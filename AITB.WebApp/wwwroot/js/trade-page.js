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
        this.priceUpdateTimer = null;
        this.botStatusTimer = null;
        
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
            
            // Start live price updates using our chart API
            this.startLivePriceUpdates();
            
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
            // Use our new chart API endpoint with auto-backfill
            const response = await fetch(`/api/chart/candles?symbol=${this.currentSymbol}&interval=${this.currentInterval}&limit=500`);
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

            // Restart live price updates for new symbol
            this.startLivePriceUpdates();

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

    // Enhanced price updates using our new chart API
    async updateLivePrice() {
        try {
            const response = await fetch(`/api/chart/price?symbol=${this.currentSymbol}`);
            if (response.ok) {
                const priceData = await response.json();
                
                // Update price display
                this.updatePriceDisplay(this.currentSymbol, parseFloat(priceData.price));
                
                // Store updated market data
                const market = this.markets.get(this.currentSymbol);
                if (market) {
                    market.price = parseFloat(priceData.price).toFixed(4);
                    market.lastUpdate = priceData.timestamp;
                    this.updateMarketItem(this.currentSymbol, market);
                }
                
                console.log(`Price update: ${this.currentSymbol} = $${priceData.price} (${priceData.source})`);
            }
        } catch (error) {
            console.error('Error updating live price:', error);
        }
    }

    startLivePriceUpdates() {
        // Stop existing timer if any
        if (this.priceUpdateTimer) {
            clearInterval(this.priceUpdateTimer);
        }

        // Update price every 2 seconds
        this.priceUpdateTimer = setInterval(() => {
            this.updateLivePrice();
        }, 2000);

        // Initial update
        this.updateLivePrice();
        
        console.log('Started live price updates (2s interval)');
    }

    stopLivePriceUpdates() {
        if (this.priceUpdateTimer) {
            clearInterval(this.priceUpdateTimer);
            this.priceUpdateTimer = null;
            console.log('Stopped live price updates');
        }
    }

    stopBotStatusPolling() {
        if (this.botStatusTimer) {
            clearInterval(this.botStatusTimer);
            this.botStatusTimer = null;
            console.log('Stopped bot status polling');
        }
    }

    cleanup() {
        this.stopLivePriceUpdates();
        this.stopBotStatusPolling();
        if (this.connection) {
            this.connection.stop();
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

        // Bot control buttons - Real H3 Implementation
        this.setupBotControls();
    }

    setupBotControls() {
        const startBtn = document.querySelector('.btn-start');
        const pauseBtn = document.querySelector('.btn-pause');
        const stopBtn = document.querySelector('.btn-stop');
        
        if (startBtn) {
            startBtn.addEventListener('click', async () => {
                await this.controlBot('start', startBtn);
            });
        }
        
        if (pauseBtn) {
            pauseBtn.addEventListener('click', async () => {
                await this.controlBot('pause', pauseBtn);
            });
        }
        
        if (stopBtn) {
            stopBtn.addEventListener('click', async () => {
                await this.controlBot('stop', stopBtn);
            });
        }

        // Start bot status polling
        this.startBotStatusPolling();
    }

    async controlBot(action, buttonElement) {
        try {
            // Disable button and show loading state
            const originalText = buttonElement.textContent;
            buttonElement.disabled = true;
            buttonElement.textContent = `${action.charAt(0).toUpperCase() + action.slice(1)}ing...`;

            const response = await fetch('/api/bot/control', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    action: action,
                    symbol: this.currentSymbol,
                    timeframe: this.currentInterval
                })
            });

            const result = await response.json();

            if (response.ok) {
                console.log(`Bot ${action} successful:`, result);
                this.showSuccess(`Bot ${action}ed successfully`);
                
                // Update button states
                this.updateBotButtonStates(action);
                
                // Force status update
                setTimeout(() => this.updateBotStatus(), 500);
            } else {
                console.error(`Bot ${action} failed:`, result);
                this.showError(result.error || `Failed to ${action} bot`);
            }
        } catch (error) {
            console.error(`Error ${action}ing bot:`, error);
            this.showError(`Network error: Failed to ${action} bot`);
        } finally {
            // Re-enable button
            buttonElement.disabled = false;
            buttonElement.textContent = originalText;
        }
    }

    updateBotButtonStates(currentAction) {
        const startBtn = document.querySelector('.btn-start');
        const pauseBtn = document.querySelector('.btn-pause');
        const stopBtn = document.querySelector('.btn-stop');

        // Reset all buttons
        [startBtn, pauseBtn, stopBtn].forEach(btn => {
            if (btn) {
                btn.classList.remove('active', 'disabled');
                btn.disabled = false;
            }
        });

        // Set active state based on current action
        switch (currentAction) {
            case 'start':
                if (startBtn) startBtn.classList.add('active');
                if (stopBtn) stopBtn.disabled = false;
                if (pauseBtn) pauseBtn.disabled = false;
                break;
            case 'pause':
                if (pauseBtn) pauseBtn.classList.add('active');
                if (startBtn) startBtn.disabled = false;
                if (stopBtn) stopBtn.disabled = false;
                break;
            case 'stop':
                if (stopBtn) stopBtn.classList.add('active');
                if (startBtn) startBtn.disabled = false;
                if (pauseBtn) pauseBtn.disabled = true;
                break;
        }
    }

    startBotStatusPolling() {
        // Poll bot status every 3 seconds
        if (this.botStatusTimer) {
            clearInterval(this.botStatusTimer);
        }

        this.botStatusTimer = setInterval(() => {
            this.updateBotStatus();
        }, 3000);

        // Initial status update
        this.updateBotStatus();
        
        console.log('Started bot status polling (3s interval)');
    }

    async updateBotStatus() {
        try {
            const response = await fetch('/api/bot/status');
            if (response.ok) {
                const status = await response.json();
                this.displayBotStatus(status);
            } else {
                console.warn('Failed to fetch bot status:', response.status);
            }
        } catch (error) {
            console.error('Error fetching bot status:', error);
        }
    }

    displayBotStatus(status) {
        try {
            // Update Bot Status card
            const botStateElement = document.querySelector('[data-bot="state"]');
            const botSymbolElement = document.querySelector('[data-bot="symbol"]');
            const botTimeframeElement = document.querySelector('[data-bot="timeframe"]');
            const botPositionsElement = document.querySelector('[data-bot="positions"]');
            const botPnlElement = document.querySelector('[data-bot="pnl"]');
            const botHeartbeatElement = document.querySelector('[data-bot="heartbeat"]');

            if (botStateElement) {
                botStateElement.textContent = status.state || 'Unknown';
                botStateElement.className = `bot-value ${this.getBotStatusClass(status.state)}`;
            }

            if (botSymbolElement) {
                botSymbolElement.textContent = status.symbol || this.currentSymbol;
            }

            if (botTimeframeElement) {
                botTimeframeElement.textContent = status.timeframe || this.currentInterval;
            }

            if (botPositionsElement && status.positions) {
                const positionValue = status.positions.total_value || 0;
                botPositionsElement.textContent = `$${parseFloat(positionValue).toFixed(2)}`;
            }

            if (botPnlElement && status.positions) {
                const pnl = status.positions.unrealized_pnl || 0;
                const pnlText = `${pnl >= 0 ? '+' : ''}$${parseFloat(pnl).toFixed(2)}`;
                botPnlElement.textContent = pnlText;
                botPnlElement.className = `bot-value ${pnl >= 0 ? 'positive' : 'negative'}`;
            }

            if (botHeartbeatElement) {
                const heartbeatTime = status.last_heartbeat ? new Date(status.last_heartbeat) : new Date();
                const timeAgo = this.getTimeAgo(heartbeatTime);
                botHeartbeatElement.textContent = timeAgo;
                
                // Color based on heartbeat freshness
                const heartbeatClass = this.getHeartbeatClass(heartbeatTime);
                botHeartbeatElement.className = `bot-value ${heartbeatClass}`;
            }

            // Update recent signals
            if (status.recent_signals) {
                this.displayRecentSignals(status.recent_signals);
            }

            // Update button states based on current bot state
            this.updateBotButtonStates(status.state);

        } catch (error) {
            console.error('Error displaying bot status:', error);
        }
    }

    getBotStatusClass(state) {
        switch (state) {
            case 'running':
            case 'active':
                return 'positive';
            case 'paused':
                return 'warning';
            case 'stopped':
            case 'inactive':
                return 'negative';
            default:
                return 'neutral';
        }
    }

    getHeartbeatClass(heartbeatTime) {
        const now = new Date();
        const diffSeconds = (now - heartbeatTime) / 1000;
        
        if (diffSeconds < 30) return 'positive';
        if (diffSeconds < 60) return 'warning';
        return 'negative';
    }

    getTimeAgo(date) {
        const now = new Date();
        const diffSeconds = Math.floor((now - date) / 1000);
        
        if (diffSeconds < 60) return `${diffSeconds}s ago`;
        if (diffSeconds < 3600) return `${Math.floor(diffSeconds / 60)}m ago`;
        return `${Math.floor(diffSeconds / 3600)}h ago`;
    }

    displayRecentSignals(signals) {
        const signalsContainer = document.querySelector('.recent-signals');
        if (!signalsContainer || !signals) return;

        signalsContainer.innerHTML = '';

        // Show last 3 signals
        const recentSignals = signals.slice(-3);
        
        if (recentSignals.length === 0) {
            signalsContainer.innerHTML = '<div class="no-signals">No recent signals</div>';
            return;
        }

        recentSignals.forEach(signal => {
            const signalElement = document.createElement('div');
            signalElement.className = `signal-item signal-${signal.type.toLowerCase()}`;
            
            const signalTime = new Date(signal.timestamp);
            const timeAgo = this.getTimeAgo(signalTime);
            
            signalElement.innerHTML = `
                <div class="signal-type">${signal.type}</div>
                <div class="signal-symbol">${signal.symbol}</div>
                <div class="signal-confidence">${(signal.confidence * 100).toFixed(1)}%</div>
                <div class="signal-time">${timeAgo}</div>
            `;
            
            signalsContainer.appendChild(signalElement);
        });
    }

    showSuccess(message) {
        console.log(`✅ ${message}`);
        // Could implement toast notifications here
        this.showToast(message, 'success');
    }

    showError(message) {
        console.error(`❌ ${message}`);
        // Could implement toast notifications here
        this.showToast(message, 'error');
    }

    showToast(message, type = 'info') {
        // Simple toast implementation
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.textContent = message;
        
        toast.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 12px 20px;
            border-radius: 6px;
            color: white;
            font-weight: 500;
            z-index: 1000;
            transition: opacity 0.3s;
        `;
        
        if (type === 'success') {
            toast.style.backgroundColor = '#10B981';
        } else if (type === 'error') {
            toast.style.backgroundColor = '#EF4444';
        } else {
            toast.style.backgroundColor = '#3B82F6';
        }
        
        document.body.appendChild(toast);
        
        setTimeout(() => {
            toast.style.opacity = '0';
            setTimeout(() => {
                document.body.removeChild(toast);
            }, 300);
        }, 3000);
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