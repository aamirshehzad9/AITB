// Enhanced market prices loading function for Top 10 USDT markets
async function loadTop10Markets() {
    try {
        const resp = await fetch('/api/market/top10');
        if (!resp.ok) {
            throw new Error(`API returned ${resp.status}: ${resp.statusText}`);
        }
        const data = await resp.json();
        
        const marketList = document.querySelector('#market-list');
        if (!marketList) return;
        
        marketList.innerHTML = '';
        
        // Add header for Top 10 USDT Markets
        const header = document.createElement('div');
        header.classList.add('market-header');
        header.innerHTML = '<h4>Top 10 USDT Markets</h4>';
        marketList.appendChild(header);
        
        data.forEach((market, index) => {
            const li = document.createElement('li');
            li.classList.add('market-item');
            li.dataset.symbol = market.symbol;
            
            const changePercent = parseFloat(market.priceChangePercent);
            const changeClass = changePercent >= 0 ? 'positive' : 'negative';
            const changeSign = changePercent >= 0 ? '+' : '';
            
            li.innerHTML = `
                <div class="market-rank">#${index + 1}</div>
                <div class="market-symbol">${market.symbol.replace('USDT', '/USDT')}</div>
                <div class="market-price ${changeClass}">$${parseFloat(market.lastPrice).toFixed(4)}</div>
                <div class="market-change ${changeClass}">${changeSign}${changePercent.toFixed(2)}%</div>
                <div class="market-volume">${(parseFloat(market.quoteVolume) / 1000000).toFixed(1)}M</div>
            `;
            
            // Add click handler to select market
            li.addEventListener('click', () => {
                if (window.tradingInterface) {
                    window.tradingInterface.selectSymbol(market.symbol);
                }
            });
            
            marketList.appendChild(li);
        });
        
        console.log(`Loaded top ${data.length} USDT markets`);
    } catch (error) {
        console.error('Failed to load top 10 markets:', error);
        const marketList = document.querySelector('#market-list');
        if (marketList) {
            marketList.innerHTML = '<div class="error">Failed to load markets</div>';
        }
    }
}

// Load Top 10 markets every 30 seconds
setInterval(loadTop10Markets, 30000);
loadTop10Markets();

// AITB Trading Interface - Binance-style UX with Lightweight Charts and SignalR
class TradingInterface {
    constructor() {
        this.chart = null;
        this.candleSeries = null;
        this.connection = null;
        this.currentSymbol = window.initialSymbol || 'BTCUSDT';
        this.currentInterval = window.initialInterval || '1m';
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

            // Add candlestick series for OHLC data
            this.candleSeries = this.chart.addCandlestickSeries({
                upColor: '#26a69a',
                downColor: '#ef5350',
                borderVisible: false,
                wickUpColor: '#26a69a',
                wickDownColor: '#ef5350'
            });

            // Load initial candlestick data
            await this.loadCandlestickData();

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

    async loadCandlestickData() {
        try {
            const response = await fetch(`/api/klines/candles?symbol=${this.currentSymbol}&interval=${this.currentInterval}&limit=500`);
            if (!response.ok) {
                throw new Error(`Failed to load candlestick data: ${response.status}`);
            }
            
            const candleData = await response.json();
            
            // Format data for Lightweight Charts
            const formattedData = candleData.map(candle => ({
                time: candle.time,
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close
            }));
            
            // Set data to candlestick series
            this.candleSeries.setData(formattedData);
            
            console.log(`Loaded ${formattedData.length} candlesticks for ${this.currentSymbol} ${this.currentInterval}`);
            
            // Update symbol header
            this.updateSymbolHeader();
            
        } catch (error) {
            console.error('Failed to load candlestick data:', error);
            this.showError('Failed to load chart data');
        }
    }

    updateSymbolHeader() {
        const symbolInfo = document.querySelector('.symbol-info h2');
        const symbolChange = document.querySelector('.symbol-change');
        
        if (symbolInfo) {
            symbolInfo.textContent = this.currentSymbol.replace('USDT', '/USDT');
        }
        
        // Get market data for this symbol
        const market = this.markets.get(this.currentSymbol);
        if (market && symbolChange) {
            const changePercent = parseFloat(market.priceChangePercent);
            const changeClass = changePercent >= 0 ? 'positive' : 'negative';
            const changeSign = changePercent >= 0 ? '+' : '';
            
            symbolChange.innerHTML = `
                <span class="current-price ${changeClass}">$${market.price}</span>
                <span class="price-change ${changeClass}">${changeSign}${market.priceChangePercent}%</span>
            `;
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
            // Load top 10 USDT markets
            const response = await fetch('/api/market/top10');
            if (!response.ok) {
                throw new Error(`Failed to load markets: ${response.status}`);
            }
            
            const top10Markets = await response.json();
            
            // Clear existing markets
            this.markets.clear();
            
            // Store markets data
            top10Markets.forEach(market => {
                this.markets.set(market.symbol, {
                    symbol: market.symbol,
                    displaySymbol: market.symbol.replace('USDT', '/USDT'),
                    price: parseFloat(market.lastPrice).toFixed(4),
                    priceChangePercent: parseFloat(market.priceChangePercent).toFixed(2),
                    volume: market.volume,
                    quoteVolume: market.quoteVolume
                });
            });

            console.log(`Loaded ${this.markets.size} top USDT markets`);
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

            // Load new candlestick data
            await this.loadCandlestickData();

            // Start new stream
            await this.startBinanceStream();

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

            // Update current interval
            this.currentInterval = interval;

            // Reload candlestick data with new interval
            await this.loadCandlestickData();

            console.log(`Selected timeframe: ${interval}`);
        } catch (error) {
            console.error('Failed to select timeframe:', error);
            this.showError('Failed to change timeframe');
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
                const candlestick = {
                    time: data.closeTime / 1000, // Convert to seconds
                    open: parseFloat(data.open),
                    high: parseFloat(data.high),
                    low: parseFloat(data.low),
                    close: parseFloat(data.close)
                };

                // Update chart with new candlestick
                this.candleSeries.update(candlestick);
                
                // Update symbol header with current price
                this.updatePriceDisplay(data.symbol, parseFloat(data.close));
            }
        } catch (error) {
            console.error('Error handling kline update:', error);
        }
    }

    updatePriceDisplay(symbol, price) {
        // Update current price in header
        const symbolChange = document.querySelector('.symbol-change');
        if (symbolChange && symbol === this.currentSymbol) {
            const market = this.markets.get(symbol);
            if (market) {
                market.price = price.toFixed(4);
                
                const changePercent = parseFloat(market.priceChangePercent);
                const changeClass = changePercent >= 0 ? 'positive' : 'negative';
                const changeSign = changePercent >= 0 ? '+' : '';
                
                symbolChange.innerHTML = `
                    <span class="current-price ${changeClass}">$${market.price}</span>
                    <span class="price-change ${changeClass}">${changeSign}${market.priceChangePercent}%</span>
                `;
                
                // Add price change animation
                const priceElement = symbolChange.querySelector('.current-price');
                if (priceElement) {
                    priceElement.style.transition = 'color 0.3s';
                    priceElement.style.color = '#F0B90B';
                    setTimeout(() => {
                        priceElement.style.color = '';
                    }, 300);
                }
            }
        }
        
        // Update market list item
        this.updateMarketItem(symbol, { price: price.toFixed(4) });
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