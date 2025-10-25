// Market prices loading function
async function loadMarketPrices() {
    const resp = await fetch('/api/market/prices');
    const data = await resp.json();
    const marketList = document.querySelector('#market-list');
    marketList.innerHTML = '';
    data.slice(0, 20).forEach(item => {
        const symbol = item.symbol;
        if (symbol.endsWith('USDT')) {
            const li = document.createElement('li');
            li.classList.add('market-item');
            li.innerHTML = `
                <span>${symbol}</span>
                <span>${parseFloat(item.price).toFixed(2)}</span>
            `;
            marketList.appendChild(li);
        }
    });
}

setInterval(loadMarketPrices, 5000);
loadMarketPrices();

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
            await this.startBinanceStream();
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
                .configureLogging(signalR.LogLevel.Information)
                .withAutomaticReconnect()
                .build();

            // Handle ticker updates from Binance WebSocket
            this.connection.on("ReceiveTicker", (symbol, data) => {
                this.handleTickerUpdate(symbol, data);
            });

            // Handle kline updates from Binance WebSocket
            this.connection.on("ReceiveKline", (data) => {
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
                this.startBinanceStream();
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
            const chartContainer = document.getElementById('chart') || document.getElementById('candles');
            if (!chartContainer) {
                throw new Error('Chart container not found');
            }

            this.chart = LightweightCharts.createChart(chartContainer, {
                width: chartContainer.clientWidth,
                height: 600,
                layout: {
                    background: { color: '#0B0E11' },
                    textColor: '#DDD',
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

            // Add line series for real-time price
            this.candleSeries = this.chart.addLineSeries({ 
                color: '#F0B90B',
                lineWidth: 2
            });

            // Handle chart resize
            window.addEventListener('resize', () => {
                this.chart.applyOptions({
                    width: chartContainer.clientWidth,
                    height: 600,
                });
            });

            console.log('Chart initialized successfully');
        } catch (error) {
            console.error('Failed to initialize chart:', error);
            throw error;
        }
    }

    async startBinanceStream() {
        try {
            // Start the Binance WebSocket stream for the current symbol
            const response = await fetch(`/api/market/stream/${this.currentSymbol}`);
            const result = await response.json();
            
            if (response.ok) {
                console.log(`Started Binance stream: ${result.message}`);
            } else {
                console.error(`Failed to start stream: ${result.error}`);
                this.showError(`Failed to start stream: ${result.error}`);
            }
        } catch (error) {
            console.error('Error starting Binance stream:', error);
            this.showError('Failed to start Binance stream');
        }
    }

    async loadMarkets() {
        try {
            // Load some popular markets for demo
            const popularSymbols = ['BTCUSDT', 'ETHUSDT', 'ADAUSDT', 'DOTUSDT', 'LINKUSDT'];
            
            for (const symbol of popularSymbols) {
                try {
                    const response = await fetch(`/api/market/ticker/${symbol}`);
                    if (response.ok) {
                        const ticker = await response.json();
                        this.markets.set(symbol, {
                            symbol,
                            displaySymbol: symbol.replace('USDT', '/USDT'),
                            price: parseFloat(ticker.lastPrice || ticker.c || '0').toFixed(2),
                            priceChangePercent: parseFloat(ticker.priceChangePercent || ticker.P || '0').toFixed(2)
                        });
                    }
                } catch (err) {
                    console.warn(`Failed to load ticker for ${symbol}:`, err);
                }
            }

            console.log(`Loaded ${this.markets.size} markets`);
            this.updateMarketsList();
        } catch (error) {
            console.error('Failed to load markets:', error);
            this.showError('Failed to load markets');
        }
    }

    updateMarketsList() {
        const marketsList = document.querySelector('#market-list') || document.querySelector('.markets-list');
        if (!marketsList) return;

        marketsList.innerHTML = '';

        this.markets.forEach(market => {
            const marketItem = this.createMarketItem(market);
            marketsList.appendChild(marketItem);
        });
    }

    createMarketItem(market) {
        const item = document.createElement('li');
        item.className = 'market-item';
        item.dataset.symbol = market.symbol;
        
        if (market.symbol === this.currentSymbol) {
            item.classList.add('active');
        }

        const priceChangeClass = parseFloat(market.priceChangePercent) >= 0 ? 'positive' : 'negative';
        const priceChangeSign = parseFloat(market.priceChangePercent) >= 0 ? '+' : '';

        item.innerHTML = `
            <span class="market-symbol">${market.displaySymbol}</span>
            <span class="market-price ${priceChangeClass}">$${market.price}</span>
            <span class="market-change ${priceChangeClass}">${priceChangeSign}${market.priceChangePercent}%</span>
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

            // Update current symbol
            this.currentSymbol = symbol;

            // Start new stream
            await this.startBinanceStream();

            console.log(`Selected symbol: ${symbol}`);
        } catch (error) {
            console.error('Failed to select symbol:', error);
            this.showError('Failed to change symbol');
        }
    }

    handleTickerUpdate(symbol, data) {
        try {
            if (symbol === this.currentSymbol) {
                const price = parseFloat(data.price);
                const timestamp = data.timestamp / 1000; // Convert to seconds

                // Update chart with new price point
                this.candleSeries.update({ 
                    time: timestamp, 
                    value: price 
                });

                // Update price display
                const priceElements = document.querySelectorAll(`#price-${symbol}, .current-price`);
                priceElements.forEach(el => {
                    if (el) {
                        el.textContent = `$${price.toFixed(2)}`;
                        
                        // Add price change animation
                        el.style.transition = 'color 0.3s';
                        el.style.color = '#F0B90B';
                        setTimeout(() => {
                            el.style.color = '';
                        }, 300);
                    }
                });

                // Update market list
                const market = this.markets.get(symbol);
                if (market) {
                    market.price = price.toFixed(2);
                    market.priceChangePercent = parseFloat(data.priceChange || '0').toFixed(2);
                    this.updateMarketItem(symbol, market);
                }
            }
        } catch (error) {
            console.error('Error handling ticker update:', error);
        }
    }

    handleKlineUpdate(data) {
        try {
            if (data && data.symbol === this.currentSymbol) {
                const price = parseFloat(data.close);
                const timestamp = data.closeTime / 1000; // Convert to seconds

                // Update chart
                this.candleSeries.update({ 
                    time: timestamp, 
                    value: price 
                });
            }
        } catch (error) {
            console.error('Error handling kline update:', error);
        }
    }

    updateMarketItem(symbol, market) {
        const marketItem = document.querySelector(`[data-symbol="${symbol}"]`);
        if (marketItem) {
            const priceElement = marketItem.querySelector('.market-price');
            const changeElement = marketItem.querySelector('.market-change');
            
            if (priceElement && changeElement) {
                const priceChangeClass = parseFloat(market.priceChangePercent) >= 0 ? 'positive' : 'negative';
                const priceChangeSign = parseFloat(market.priceChangePercent) >= 0 ? '+' : '';

                priceElement.textContent = `$${market.price}`;
                priceElement.className = `market-price ${priceChangeClass}`;
                
                changeElement.textContent = `${priceChangeSign}${market.priceChangePercent}%`;
                changeElement.className = `market-change ${priceChangeClass}`;
            }
        }
    }

    updateConnectionStatus(connected) {
        this.isConnected = connected !== false;
        const statusElements = document.querySelectorAll('[data-account="data-feed"], .connection-status');
        statusElements.forEach(statusElement => {
            if (statusElement) {
                statusElement.textContent = this.isConnected ? 'Connected' : 'Disconnected';
                statusElement.className = this.isConnected ? 'account-value positive' : 'account-value negative';
            }
        });
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
            });
        }
        
        if (stopBtn) {
            stopBtn.addEventListener('click', () => {
                console.log('Stop bot clicked');
                this.showInfo('Bot stopped (demo mode)');
            });
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