import React, { useState, useEffect } from 'react';
import { Layout, Card, Row, Col, Statistic, Table, Switch, Button, notification, Spin } from 'antd';
import { 
  DollarCircleOutlined, 
  RiseOutlined, 
  FallOutlined, 
  RobotOutlined,
  ApiOutlined,
  MonitorOutlined 
} from '@ant-design/icons';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts';
import axios from 'axios';
import moment from 'moment';

const { Header, Content, Footer } = Layout;
const { Meta } = Card;

// API Configuration
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';
const INFERENCE_URL = process.env.REACT_APP_INFERENCE_URL || 'http://localhost:8001';
const GRAFANA_URL = process.env.REACT_APP_GRAFANA_URL || 'http://localhost:3001';

function App() {
  const [loading, setLoading] = useState(true);
  const [botStatus, setBotStatus] = useState(null);
  const [inferenceStatus, setInferenceStatus] = useState(null);
  const [trades, setTrades] = useState([]);
  const [performanceData, setPerformanceData] = useState([]);
  const [isTrading, setIsTrading] = useState(false);

  // Fetch data from APIs
  useEffect(() => {
    fetchAllData();
    const interval = setInterval(fetchAllData, 30000); // Update every 30 seconds
    return () => clearInterval(interval);
  }, []);

  const fetchAllData = async () => {
    try {
      // Fetch bot status
      const botResponse = await axios.get(`${API_BASE_URL}/health`, { timeout: 5000 });
      setBotStatus(botResponse.data);

      // Fetch inference status  
      const inferenceResponse = await axios.get(`${INFERENCE_URL}/health`, { timeout: 5000 });
      setInferenceStatus(inferenceResponse.data);

      // Fetch recent trades
      const tradesResponse = await axios.get(`${API_BASE_URL}/trades?limit=20`, { timeout: 5000 });
      setTrades(tradesResponse.data);

      // Set trading status
      setIsTrading(botResponse.data.is_running);

      // Generate mock performance data (replace with real data later)
      const mockPerformanceData = generateMockPerformanceData();
      setPerformanceData(mockPerformanceData);

      setLoading(false);
    } catch (error) {
      console.error('Error fetching data:', error);
      notification.error({
        message: 'Connection Error',
        description: 'Failed to connect to AITB services. Please check if all services are running.',
      });
      setLoading(false);
    }
  };

  const generateMockPerformanceData = () => {
    const data = [];
    const baseValue = 1000;
    for (let i = 0; i < 24; i++) {
      data.push({
        time: moment().subtract(24 - i, 'hours').format('HH:mm'),
        pnl: baseValue + Math.random() * 200 - 100,
        trades: Math.floor(Math.random() * 10),
        accuracy: 0.6 + Math.random() * 0.3
      });
    }
    return data;
  };

  const handleTradingToggle = async (checked) => {
    try {
      // This would call an API to start/stop trading
      setIsTrading(checked);
      notification.success({
        message: checked ? 'Trading Started' : 'Trading Stopped',
        description: `AITB trading bot is now ${checked ? 'active' : 'inactive'}.`,
      });
    } catch (error) {
      notification.error({
        message: 'Error',
        description: 'Failed to toggle trading status.',
      });
    }
  };

  const executeManualTrade = async (pair, side, amount) => {
    try {
      await axios.post(`${API_BASE_URL}/manual_trade`, { pair, side, amount });
      notification.success({
        message: 'Trade Executed',
        description: `Manual ${side} order for ${amount} ${pair} has been executed.`,
      });
      fetchAllData(); // Refresh data
    } catch (error) {
      notification.error({
        message: 'Trade Failed',
        description: 'Failed to execute manual trade.',
      });
    }
  };

  // Table columns for trades
  const tradeColumns = [
    {
      title: 'Time',
      dataIndex: 'timestamp',
      key: 'timestamp',
      render: (text) => moment(text).format('HH:mm:ss'),
      width: 100,
    },
    {
      title: 'Pair',
      dataIndex: 'pair',
      key: 'pair',
      width: 100,
    },
    {
      title: 'Side',
      dataIndex: 'side',
      key: 'side',
      render: (text) => (
        <span style={{ color: text === 'buy' ? '#52c41a' : '#f5222d' }}>
          {text.toUpperCase()}
        </span>
      ),
      width: 80,
    },
    {
      title: 'Amount',
      dataIndex: 'amount',
      key: 'amount',
      render: (text) => parseFloat(text).toFixed(4),
      width: 100,
    },
    {
      title: 'Price',
      dataIndex: 'price',
      key: 'price',
      render: (text) => `$${parseFloat(text).toFixed(8)}`,
      width: 120,
    },
    {
      title: 'Total',
      dataIndex: 'total',
      key: 'total',
      render: (text) => `$${parseFloat(text).toFixed(2)}`,
      width: 100,
    },
    {
      title: 'Model',
      dataIndex: 'model_used',
      key: 'model_used',
      width: 100,
    },
    {
      title: 'Confidence',
      dataIndex: 'confidence',
      key: 'confidence',
      render: (text) => text ? `${(parseFloat(text) * 100).toFixed(1)}%` : 'N/A',
      width: 100,
    },
  ];

  if (loading) {
    return (
      <Layout style={{ minHeight: '100vh' }}>
        <Content style={{ display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
          <Spin size="large" />
        </Content>
      </Layout>
    );
  }

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header style={{ background: '#001529', color: 'white', padding: '0 50px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <h1 style={{ color: 'white', margin: 0 }}>
            <RobotOutlined style={{ marginRight: 8 }} />
            AITB Dashboard
          </h1>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <span>Trading: </span>
            <Switch 
              checked={isTrading} 
              onChange={handleTradingToggle}
              checkedChildren="ON"
              unCheckedChildren="OFF"
            />
          </div>
        </div>
      </Header>

      <Content style={{ margin: '24px 16px', padding: 24, background: '#f0f2f5' }}>
        {/* Status Cards */}
        <Row gutter={16} style={{ marginBottom: 24 }}>
          <Col span={8}>
            <Card>
              <Statistic
                title="Trading Bot Status"
                value={botStatus?.status || 'Unknown'}
                prefix={<RobotOutlined />}
                valueStyle={{ color: botStatus?.status === 'healthy' ? '#3f8600' : '#cf1322' }}
              />
              <div style={{ marginTop: 8, fontSize: 12, color: '#666' }}>
                Uptime: {botStatus?.uptime ? `${Math.floor(botStatus.uptime / 3600)}h ${Math.floor((botStatus.uptime % 3600) / 60)}m` : 'N/A'}
              </div>
            </Card>
          </Col>
          <Col span={8}>
            <Card>
              <Statistic
                title="AI Models"
                value={inferenceStatus?.models_loaded || 0}
                prefix={<ApiOutlined />}
                suffix="loaded"
                valueStyle={{ color: '#1890ff' }}
              />
              <div style={{ marginTop: 8, fontSize: 12, color: '#666' }}>
                CPU: {inferenceStatus?.system_info?.cpu_percent?.toFixed(1) || 'N/A'}% | 
                Memory: {inferenceStatus?.system_info?.memory_percent?.toFixed(1) || 'N/A'}%
              </div>
            </Card>
          </Col>
          <Col span={8}>
            <Card>
              <Statistic
                title="Active Pairs"
                value={botStatus?.active_pairs || 0}
                prefix={<MonitorOutlined />}
                valueStyle={{ color: '#722ed1' }}
              />
              <div style={{ marginTop: 8, fontSize: 12, color: '#666' }}>
                Mode: {botStatus?.trading_mode || 'N/A'}
              </div>
            </Card>
          </Col>
        </Row>

        {/* Performance Chart */}
        <Row gutter={16} style={{ marginBottom: 24 }}>
          <Col span={24}>
            <Card title="Performance Overview (Last 24 Hours)">
              <ResponsiveContainer width="100%" height={300}>
                <AreaChart data={performanceData}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="time" />
                  <YAxis />
                  <Tooltip />
                  <Area 
                    type="monotone" 
                    dataKey="pnl" 
                    stroke="#8884d8" 
                    fill="#8884d8" 
                    fillOpacity={0.3} 
                  />
                </AreaChart>
              </ResponsiveContainer>
            </Card>
          </Col>
        </Row>

        {/* Quick Actions */}
        <Row gutter={16} style={{ marginBottom: 24 }}>
          <Col span={24}>
            <Card title="Quick Actions">
              <Row gutter={16}>
                <Col span={6}>
                  <Button 
                    type="primary" 
                    onClick={() => executeManualTrade('BTC/USDT', 'buy', 0.001)}
                    style={{ width: '100%' }}
                  >
                    Buy BTC
                  </Button>
                </Col>
                <Col span={6}>
                  <Button 
                    danger
                    onClick={() => executeManualTrade('BTC/USDT', 'sell', 0.001)}
                    style={{ width: '100%' }}
                  >
                    Sell BTC
                  </Button>
                </Col>
                <Col span={6}>
                  <Button 
                    onClick={() => window.open(GRAFANA_URL, '_blank')}
                    style={{ width: '100%' }}
                  >
                    View Grafana
                  </Button>
                </Col>
                <Col span={6}>
                  <Button 
                    onClick={fetchAllData}
                    style={{ width: '100%' }}
                  >
                    Refresh Data
                  </Button>
                </Col>
              </Row>
            </Card>
          </Col>
        </Row>

        {/* Recent Trades Table */}
        <Row gutter={16}>
          <Col span={24}>
            <Card title="Recent Trades">
              <Table
                columns={tradeColumns}
                dataSource={trades}
                rowKey="id"
                size="small"
                pagination={{ pageSize: 10 }}
                scroll={{ x: 800 }}
              />
            </Card>
          </Col>
        </Row>
      </Content>

      <Footer style={{ textAlign: 'center' }}>
        AITB Dashboard ©2024 | AI-Powered Trading Platform
      </Footer>
    </Layout>
  );
}

export default App;