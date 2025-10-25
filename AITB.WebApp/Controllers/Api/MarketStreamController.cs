using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using AITB.WebApp.Hubs;
using AITB.WebApp.Services;
using System.Text.Json;

namespace AITB.WebApp.Controllers.Api
{
    [ApiController]
    [Route("api/market")]
    public class MarketStreamController : ControllerBase
    {
        private readonly BinanceStreamService _stream;
        private readonly BinanceHttpService _httpService;
        private readonly IHubContext<MarketHub> _hub;
        private readonly ILogger<MarketStreamController> _logger;
        private static readonly Dictionary<string, Task> _activeStreams = new();

        public MarketStreamController(
            BinanceStreamService stream, 
            BinanceHttpService httpService,
            IHubContext<MarketHub> hub,
            ILogger<MarketStreamController> logger)
        {
            _stream = stream;
            _httpService = httpService;
            _hub = hub;
            _logger = logger;
        }

        [HttpGet("stream/{symbol}")]
        public async Task<IActionResult> StreamSymbol(string symbol)
        {
            if (!_httpService.HasValidCredentials())
            {
                _logger.LogWarning("Binance API credentials missing - cannot stream {Symbol}", symbol);
                return Unauthorized(new { error = "Binance API credentials required", symbol });
            }

            var streamKey = symbol.ToUpper();
            
            // Check if stream is already active
            if (_activeStreams.ContainsKey(streamKey))
            {
                _logger.LogInformation("Stream for {Symbol} already active", symbol);
                return Ok(new { message = $"Stream for {symbol} is already active", symbol = streamKey });
            }

            // Start new stream
            var streamTask = Task.Run(async () =>
            {
                try
                {
                    _logger.LogInformation("Starting ticker stream for {Symbol}", symbol);
                    
                    await foreach (var data in _stream.SubscribeTickerAsync(symbol))
                    {
                        try
                        {
                            // Extract price and other relevant data
                            var price = data.GetProperty("c").GetString(); // Current price
                            var priceChange = data.GetProperty("P").GetString(); // Price change percent
                            var volume = data.GetProperty("v").GetString(); // Volume
                            var symbol24h = data.GetProperty("s").GetString(); // Symbol
                            
                            // Send to all connected clients
                            await _hub.Clients.All.SendAsync("ReceiveTicker", symbol24h, new
                            {
                                symbol = symbol24h,
                                price,
                                priceChange,
                                volume,
                                timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                                raw = data
                            });
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Error processing ticker data for {Symbol}", symbol);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in ticker stream for {Symbol}", symbol);
                }
                finally
                {
                    _activeStreams.Remove(streamKey);
                    _logger.LogInformation("Ticker stream ended for {Symbol}", symbol);
                }
            });

            _activeStreams[streamKey] = streamTask;
            
            return Ok(new { 
                message = $"Started ticker stream for {symbol}", 
                symbol = streamKey,
                timestamp = DateTimeOffset.UtcNow
            });
        }

        [HttpGet("klines/{symbol}")]
        public async Task<IActionResult> StreamKlines(string symbol, [FromQuery] string interval = "1m")
        {
            if (!_httpService.HasValidCredentials())
            {
                return Unauthorized(new { error = "Binance API credentials required", symbol, interval });
            }

            var streamKey = $"{symbol.ToUpper()}_KLINE_{interval}";
            
            if (_activeStreams.ContainsKey(streamKey))
            {
                return Ok(new { message = $"Kline stream for {symbol} {interval} is already active", streamKey });
            }

            var streamTask = Task.Run(async () =>
            {
                try
                {
                    _logger.LogInformation("Starting kline stream for {Symbol} {Interval}", symbol, interval);
                    
                    await foreach (var data in _stream.SubscribeKlineAsync(symbol, interval))
                    {
                        try
                        {
                            var kline = data.GetProperty("k");
                            var klineData = new
                            {
                                symbol = kline.GetProperty("s").GetString(),
                                openTime = kline.GetProperty("t").GetInt64(),
                                closeTime = kline.GetProperty("T").GetInt64(),
                                interval = kline.GetProperty("i").GetString(),
                                open = kline.GetProperty("o").GetString(),
                                high = kline.GetProperty("h").GetString(),
                                low = kline.GetProperty("l").GetString(),
                                close = kline.GetProperty("c").GetString(),
                                volume = kline.GetProperty("v").GetString(),
                                isClosed = kline.GetProperty("x").GetBoolean()
                            };
                            
                            await _hub.Clients.All.SendAsync("ReceiveKline", klineData);
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Error processing kline data for {Symbol}", symbol);
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in kline stream for {Symbol}", symbol);
                }
                finally
                {
                    _activeStreams.Remove(streamKey);
                }
            });

            _activeStreams[streamKey] = streamTask;
            
            return Ok(new { 
                message = $"Started kline stream for {symbol} {interval}", 
                streamKey,
                timestamp = DateTimeOffset.UtcNow
            });
        }

        [HttpGet("ticker/{symbol}")]
        public async Task<IActionResult> GetTicker(string symbol)
        {
            try
            {
                var ticker = await _httpService.GetTickerAsync(symbol);
                if (ticker == null)
                {
                    return NotFound(new { error = $"Ticker not found for symbol {symbol}" });
                }
                
                return Ok(ticker);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting ticker for {Symbol}", symbol);
                return StatusCode(500, new { error = "Internal server error", symbol });
            }
        }

        [HttpGet("status")]
        public IActionResult GetStreamStatus()
        {
            var activeStreams = _activeStreams.Keys.ToArray();
            return Ok(new
            {
                activeStreams,
                count = activeStreams.Length,
                hasCredentials = _httpService.HasValidCredentials(),
                timestamp = DateTimeOffset.UtcNow
            });
        }

        [HttpDelete("stream/{symbol}")]
        public IActionResult StopStream(string symbol)
        {
            var streamKey = symbol.ToUpper();
            
            if (_activeStreams.ContainsKey(streamKey))
            {
                // Note: In a production environment, you'd want a cancellation token system
                _activeStreams.Remove(streamKey);
                _logger.LogInformation("Stream stopped for {Symbol}", symbol);
                return Ok(new { message = $"Stream stopped for {symbol}", symbol = streamKey });
            }
            
            return NotFound(new { error = $"No active stream found for {symbol}", symbol = streamKey });
        }
    }
}