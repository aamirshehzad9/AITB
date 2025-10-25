// AITB Trading Interface - Binance-style UX with Lightweight Charts and SignalR
class TradingInterface {
    constructor() {
        this.chart = null;
        this.candleSeries = null;
        this.connection = null;
        this.currentSymbol = window.initialSymbol || 'BTCUSDT';
        this.currentInterval = window.initialInterval || '15m';
        this.isConnected = false;
        this.markets = new Map();
        
        this.init();
    }

    async init() {
        try {
            await this.initSignalR();
            await this.initChart();
            await this.loadMarkets();
            await this.loadInitialData();
            this.setupEventListeners();
            this.updateConnectionStatus();
            
            console.log('⚡ Connected to market stream');
            console.log('Trading interface initialized successfully');
        } catch (error) {
            console.error('Failed to initialize trading interface:', error);
            this.showError('Failed to initialize trading interface');
        }
    }

    async initSignalR() {
        try {
            // Create SignalR connection
            this.connection = new signalR.HubConnectionBuilder()
                .withUrl("/marketHub")
                .withAutomaticReconnect()
                .build();

            // Handle price updates
            this.connection.on("PriceUpdate", (data) => {
                this.handlePriceUpdate(data);
            });

            // Handle kline updates
            this.connection.on("KlineUpdate", (data) => {
                this.handleKlineUpdate(data);
            });

            // Handle connection events
            this.connection.onreconnecting(() => {
                console.log('SignalR reconnecting...');
                this.updateConnectionStatus(false);
            });

            this.connection.onreconnected(() => {
                console.log('SignalR reconnected');
                this.updateConnectionStatus(true);
                this.subscribeToSymbol(this.currentSymbol, this.currentInterval);
            });

            this.connection.onclose(() => {
                console.log('SignalR connection closed');
                this.updateConnectionStatus(false);
            });

            // Start connection
            await this.connection.start();
            this.updateConnectionStatus(true);
            console.log('⚡ Connected to market stream');

        } catch (error) {
            console.error('SignalR connection failed:', error);
            throw error;
        }
    }

    async initChart() {
        try {
            // Create lightweight chart
            const chartContainer = document.getElementById('candles');
            if (!chartContainer) {
                throw new Error('Chart container not found');
            }

            this.chart = LightweightCharts.createChart(chartContainer, {
                width: chartContainer.clientWidth,
                height: 640,
                layout: {
                    background: { color: '#181A20' },
                    textColor: '#FAFAFA',
                },
                grid: {
                    vertLines: { color: '#2B3139' },
                    horzLines: { color: '#2B3139' },
                },
                crosshair: {
                    mode: LightweightCharts.CrosshairMode.Normal,
                },
                rightPriceScale: {
                    borderColor: '#2B3139',
                },
                timeScale: {
                    borderColor: '#2B3139',
                    timeVisible: true,
                    secondsVisible: false,
                },
            });

            // Add candlestick series
            this.candleSeries = this.chart.addCandlestickSeries({
                upColor: '#0ECB81',
                downColor: '#F6465D',
                borderDownColor: '#F6465D',
                borderUpColor: '#0ECB81',
                wickDownColor: '#F6465D',
                wickUpColor: '#0ECB81',
            });

            // Handle chart resize
            window.addEventListener('resize', () => {
                this.chart.applyOptions({
                    width: chartContainer.clientWidth,
                    height: 640,
                });
            });

            console.log('Chart initialized successfully');
        } catch (error) {
            console.error('Failed to initialize chart:', error);
            throw error;
        }
    }

    async loadMarkets() {
        try {
            const response = await fetch('/api/market/markets');
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const markets = await response.json();
            this.markets.clear();
            
            const marketsList = document.querySelector('.markets-list');
            if (!marketsList) {
                throw new Error('Markets list container not found');
            }

            marketsList.innerHTML = '';

            markets.forEach(market => {
                this.markets.set(market.symbol, market);
                
                const marketItem = this.createMarketItem(market);
                marketsList.appendChild(marketItem);
            });

            console.log(`Loaded ${markets.length} markets`);
        } catch (error) {
            console.error('Failed to load markets:', error);
            this.showError('Failed to load markets');
        }
    }

    createMarketItem(market) {
        const item = document.createElement('div');
        item.className = 'market-item';
        item.dataset.symbol = market.symbol;
        
        if (market.symbol === this.currentSymbol) {
            item.classList.add('active');
        }

        const priceChangeClass = market.changePercent24h >= 0 ? 'positive' : 'negative';
        const priceChangeSign = market.changePercent24h >= 0 ? '+' : '';

        item.innerHTML = `
            <div class="market-symbol">${market.displaySymbol}</div>
            <div class="market-price">
                <div class="market-price-value ${priceChangeClass}">${market.price}</div>
                <div class="market-price-change ${priceChangeClass}">${priceChangeSign}${market.priceChangePercent}%</div>
            </div>
        `;

        item.addEventListener('click', () => {
            this.selectSymbol(market.symbol);
        });

        return item;
    }

    async selectSymbol(symbol) {
        if (symbol === this.currentSymbol) return;

        try {
            // Update UI
            document.querySelectorAll('.market-item').forEach(item => {
                item.classList.remove('active');
            });
            
            const selectedItem = document.querySelector(`[data-symbol="${symbol}"]`);
            if (selectedItem) {
                selectedItem.classList.add('active');
            }

            // Update symbol info
            const market = this.markets.get(symbol);
            if (market) {
                this.updateSymbolInfo(market);
            }

            // Unsubscribe from old symbol
            if (this.isConnected) {
                await this.connection.invoke("Unsubscribe", this.currentSymbol, this.currentInterval);
            }

            // Update current symbol
            this.currentSymbol = symbol;

            // Load new data and subscribe
            await this.loadChartData();
            if (this.isConnected) {
                await this.subscribeToSymbol(symbol, this.currentInterval);
            }

            console.log(`Selected symbol: ${symbol}`);
        } catch (error) {
            console.error('Failed to select symbol:', error);
            this.showError('Failed to change symbol');
        }
    }

    async selectTimeframe(interval) {
        if (interval === this.currentInterval) return;

        try {
            // Update UI
            document.querySelectorAll('.timeframe-pill').forEach(pill => {
                pill.classList.remove('active');
            });
            
            const selectedPill = document.querySelector(`[data-interval="${interval}"]`);
            if (selectedPill) {
                selectedPill.classList.add('active');
            }

            // Unsubscribe from old interval
            if (this.isConnected) {
                await this.connection.invoke("Unsubscribe", this.currentSymbol, this.currentInterval);
            }

            // Update current interval
            this.currentInterval = interval;

            // Load new data and subscribe
            await this.loadChartData();
            if (this.isConnected) {
                await this.subscribeToSymbol(this.currentSymbol, interval);
            }

            console.log(`Selected timeframe: ${interval}`);
        } catch (error) {
            console.error('Failed to select timeframe:', error);
            this.showError('Failed to change timeframe');
        }
    }

    async loadInitialData() {
        await this.loadChartData();
        if (this.isConnected) {
            await this.subscribeToSymbol(this.currentSymbol, this.currentInterval);
        }
    }

    async loadChartData() {
        try {
            const url = `/api/klines?symbol=${this.currentSymbol}&interval=${this.currentInterval}&limit=500`;
            const response = await fetch(url);
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const klines = await response.json();
            
            if (klines && klines.length > 0) {
                this.candleSeries.setData(klines);
                // Always call fitContent to ensure chart visibility
                this.chart.timeScale().fitContent();
                console.log(`Loaded ${klines.length} klines for ${this.currentSymbol} ${this.currentInterval}`);
            } else {
                console.warn('No kline data received');
            }
        } catch (error) {
            console.error('Failed to load chart data:', error);
            this.showError('Failed to load chart data');
        }
    }

    async subscribeToSymbol(symbol, interval) {
        try {
            if (this.connection && this.isConnected) {
                await this.connection.invoke("Subscribe", symbol, interval);
                console.log(`Subscribed to ${symbol} ${interval}`);
            }
        } catch (error) {
            console.error('Failed to subscribe to symbol:', error);
        }
    }

    handlePriceUpdate(data) {
        try {
            if (data && data.symbol) {
                const market = this.markets.get(data.symbol);
                if (market) {
                    // Update market data
                    market.price = data.price;
                    market.priceChangePercent = data.priceChangePercent;

                    // Update UI with animation
                    const marketItem = document.querySelector(`[data-symbol="${data.symbol}"]`);
                    if (marketItem) {
                        const priceElement = marketItem.querySelector('.market-price-value');
                        const changeElement = marketItem.querySelector('.market-price-change');
                        
                        if (priceElement && changeElement) {
                            const priceChangeClass = data.priceChangePercent >= 0 ? 'positive' : 'negative';
                            const priceChangeSign = data.priceChangePercent >= 0 ? '+' : '';

                            // Animate price change
                            priceElement.style.transition = 'color 0.3s';
                            priceElement.textContent = data.price;
                            priceElement.className = `market-price-value ${priceChangeClass}`;
                            
                            changeElement.textContent = `${priceChangeSign}${data.priceChangePercent}%`;
                            changeElement.className = `market-price-change ${priceChangeClass}`;
                        }
                    }

                    // Update symbol info if it's the current symbol
                    if (data.symbol === this.currentSymbol) {
                        this.updateSymbolInfo(market);
                    }
                }
            }
        } catch (error) {
            console.error('Error handling price update:', error);
        }
    }

    handleKlineUpdate(data) {
        try {
            if (data && data.symbol === this.currentSymbol && data.interval === this.currentInterval) {
                const kline = {
                    time: data.time / 1000, // Convert to seconds for Lightweight Charts
                    open: data.open,
                    high: data.high,
                    low: data.low,
                    close: data.close
                };

                this.candleSeries.update(kline);
            }
        } catch (error) {
            console.error('Error handling kline update:', error);
        }
    }

    updateSymbolInfo(market) {
        try {
            const symbolElement = document.querySelector('.symbol-info h2');
            const changeElement = document.querySelector('.symbol-change');
            
            if (symbolElement) {
                symbolElement.textContent = market.displaySymbol;
            }
            
            if (changeElement) {
                const priceChangeClass = market.changePercent24h >= 0 ? 'positive' : 'negative';
                const priceChangeSign = market.changePercent24h >= 0 ? '+' : '';
                
                changeElement.textContent = `${market.price} (${priceChangeSign}${market.priceChangePercent}%)`;
                changeElement.className = `symbol-change ${priceChangeClass}`;
            }
        } catch (error) {
            console.error('Error updating symbol info:', error);
        }
    }

    updateConnectionStatus(connected) {
        this.isConnected = connected !== false;
        const statusElement = document.querySelector('[data-account="data-feed"]');
        if (statusElement) {
            statusElement.textContent = this.isConnected ? 'Connected' : 'Disconnected';
            statusElement.className = this.isConnected ? 'account-value positive' : 'account-value negative';
        }
        console.log(`Connection status: ${this.isConnected ? 'Connected' : 'Disconnected'}`);
    }

    setupEventListeners() {
        // Timeframe pills
        document.querySelectorAll('.timeframe-pill').forEach(pill => {
            pill.addEventListener('click', () => {
                const interval = pill.dataset.interval;
                if (interval) {
                    this.selectTimeframe(interval);
                }
            });
        });

        // Bot control buttons
        const startBtn = document.querySelector('.btn-start');
        const stopBtn = document.querySelector('.btn-stop');
        
        if (startBtn) {
            startBtn.addEventListener('click', () => {
                console.log('Start bot clicked');
                this.showInfo('Bot started (demo mode)');
                this.updateAIInsight('ACTIVE', 85, 'Bot trading initiated');
            });
        }
        
        if (stopBtn) {
            stopBtn.addEventListener('click', () => {
                console.log('Stop bot clicked');
                this.showInfo('Bot stopped (demo mode)');
                this.updateAIInsight('PAUSED', 0, 'Bot trading halted');
            });
        }

        // Quick action buttons
        document.querySelectorAll('.btn').forEach(btn => {
            if (!btn.classList.contains('btn-start') && !btn.classList.contains('btn-stop')) {
                btn.addEventListener('click', () => {
                    console.log(`${btn.textContent} clicked`);
                    this.showInfo(`${btn.textContent} feature coming soon`);
                });
            }
        });
    }

    updateAIInsight(signal, confidence, reason) {
        const signalElement = document.querySelector('.ai-signal');
        const confidenceElement = document.querySelector('.ai-confidence');
        
        if (signalElement) {
            signalElement.textContent = signal;
            signalElement.className = `ai-signal ${signal.toLowerCase()}`;
        }
        
        if (confidenceElement) {
            confidenceElement.textContent = `${confidence}% confidence - ${reason}`;
        }
    }

    showError(message) {
        console.error(message);
        // Could implement toast notifications here
    }

    showInfo(message) {
        console.info(message);
        // Could implement toast notifications here
    }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    // Add trade-page class to body if on trade page
    if (window.location.pathname === '/trade' || window.location.pathname.startsWith('/Trade')) {
        document.body.classList.add('trade-page');
    }

    // Check if we're on the trade page
    if (document.getElementById('candles')) {
        window.tradingInterface = new TradingInterface();
    }
});

// Utility functions for bot integration
window.AITB = {
    getCurrentSymbol: () => window.tradingInterface?.currentSymbol || 'BTCUSDT',
    getCurrentInterval: () => window.tradingInterface?.currentInterval || '15m',
    getMarketData: () => window.tradingInterface?.markets || new Map(),
    
    // AI Insight integration
    updateAIInsight: (signal, confidence, reason) => {
        window.tradingInterface?.updateAIInsight(signal, confidence, reason);
    },
    
    // Account info integration
    updateAccountInfo: (balance, pnl, openPositions) => {
        const balanceElement = document.querySelector('[data-account="balance"]');
        const pnlElement = document.querySelector('[data-account="pnl"]');
        const positionsElement = document.querySelector('[data-account="positions"]');
        
        if (balanceElement) balanceElement.textContent = balance;
        if (pnlElement) {
            pnlElement.textContent = pnl;
            pnlElement.className = pnl.startsWith('+') ? 'account-value positive' : 'account-value negative';
        }
        if (positionsElement) positionsElement.textContent = openPositions;
    }
};