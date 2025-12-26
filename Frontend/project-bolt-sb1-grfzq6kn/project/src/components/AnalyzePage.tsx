import React, { useState, useRef, useEffect } from 'react';
import { ArrowLeft, Mic, Upload, Signal, Engine, Play, Pause, AlertCircle } from './icons/CustomIcons';
import { uploadAudio, analyzeResult, connectWebSocket } from '../services/api';

interface AnalyzePageProps {
  onBack: () => void;
  isBackendConnected: boolean;
}

type AnalysisMode = 'live' | 'upload';

const getPieColor = (index: number, total: number) => {
  const colors = [
    'linear-gradient(135deg, #ff6b6b 0%, #ee5a6f 100%)',
    'linear-gradient(135deg, #4ecdc4 0%, #44a3a0 100%)',
    'linear-gradient(135deg, #a29bfe 0%, #6c5ce7 100%)',
    'linear-gradient(135deg, #fd79a8 0%, #e84393 100%)',
    'linear-gradient(135deg, #fdcb6e 0%, #f39c12 100%)',
    'linear-gradient(135deg, #00b894 0%, #00a383 100%)',
  ];
  return colors[index % colors.length];
};

interface PieChartProps {
  scores: Record<string, number>;
}

const PieChart: React.FC<PieChartProps> = ({ scores }) => {
  const [animatedPercentages, setAnimatedPercentages] = useState<number[]>([]);
  const sortedScores = Object.entries(scores).sort(([, a], [, b]) => b - a);
  const total = sortedScores.reduce((sum, [, val]) => sum + val, 0);

  useEffect(() => {
    const timer = setTimeout(() => {
      setAnimatedPercentages(sortedScores.map(([, val]) => (val / total) * 100));
    }, 100);
    return () => clearTimeout(timer);
  }, [scores]);

  const createPieSlices = () => {
    let cumulativePercentage = 0;
    
    return sortedScores.map(([issue, confidence], index) => {
      const percentage = animatedPercentages[index] || 0;
      const startAngle = (cumulativePercentage / 100) * 360;
      const endAngle = startAngle + (percentage / 100) * 360;
      
      cumulativePercentage += percentage;

      const startRadians = (startAngle - 90) * (Math.PI / 180);
      const endRadians = (endAngle - 90) * (Math.PI / 180);

      const x1 = 200 + 150 * Math.cos(startRadians);
      const y1 = 200 + 150 * Math.sin(startRadians);
      const x2 = 200 + 150 * Math.cos(endRadians);
      const y2 = 200 + 150 * Math.sin(endRadians);

      const largeArcFlag = percentage > 50 ? 1 : 0;

      const pathData = [
        `M 200 200`,
        `L ${x1} ${y1}`,
        `A 150 150 0 ${largeArcFlag} 1 ${x2} ${y2}`,
        'Z'
      ].join(' ');

      return (
        <path
          key={issue}
          d={pathData}
          fill={`url(#gradient-${index})`}
          className="pie-slice"
          style={{
            animation: `fadeIn 0.8s ease-out ${index * 0.1}s both`,
            transformOrigin: '200px 200px'
          }}
        />
      );
    });
  };

  return (
    <svg viewBox="0 0 400 400" className="pie-chart">
      <defs>
        {sortedScores.map(([, ], index) => (
          <linearGradient key={index} id={`gradient-${index}`} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={index === 0 ? "#ff6b6b" : index === 1 ? "#4ecdc4" : index === 2 ? "#a29bfe" : index === 3 ? "#fd79a8" : index === 4 ? "#fdcb6e" : "#00b894"} />
            <stop offset="100%" stopColor={index === 0 ? "#ee5a6f" : index === 1 ? "#44a3a0" : index === 2 ? "#6c5ce7" : index === 3 ? "#e84393" : index === 4 ? "#f39c12" : "#00a383"} />
          </linearGradient>
        ))}
        <filter id="shadow">
          <feDropShadow dx="0" dy="0" stdDeviation="8" floodColor="#000" floodOpacity="0.3"/>
        </filter>
      </defs>
      <g filter="url(#shadow)">
        {createPieSlices()}
      </g>
      <circle cx="200" cy="200" r="80" fill="#1a1a1a" className="pie-center" />
      <g className="center-icon">
        <circle cx="200" cy="200" r="35" fill="none" stroke="#4ecdc4" strokeWidth="3" opacity="0.3"/>
        <circle cx="200" cy="200" r="25" fill="none" stroke="#4ecdc4" strokeWidth="3" opacity="0.5"/>
        <circle cx="200" cy="200" r="15" fill="#4ecdc4" opacity="0.8">
          <animate attributeName="r" values="15;18;15" dur="2s" repeatCount="indefinite"/>
          <animate attributeName="opacity" values="0.8;1;0.8" dur="2s" repeatCount="indefinite"/>
        </circle>
      </g>
    </svg>
  );
};

const AnalyzePage: React.FC<AnalyzePageProps> = ({ onBack, isBackendConnected }) => {
  const [mode, setMode] = useState<AnalysisMode | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [uploadedFile, setUploadedFile] = useState<File | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysisResult, setAnalysisResult] = useState<analyzeResult | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);

  const handleFileUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      setUploadedFile(file);
      setAnalysisResult(null);
    }
  };

  const handleAnalyzeFile = async () => {
    if (!uploadedFile || !isBackendConnected) return;

    setIsAnalyzing(true);
    try {
      const result = await uploadAudio(uploadedFile);
      setAnalysisResult(result);
    } catch (error) {
      console.error('Analysis failed:', error);
      setAnalysisResult({
        status: 'error',
        message: 'Analysis failed. Please try again.'
      });
    } finally {
      setIsAnalyzing(false);
    }
  };

  const toggleRecording = async () => {
    if (isRecording) {
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
        mediaRecorderRef.current.stop();
      }
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
      if (audioContextRef.current) {
        audioContextRef.current.close();
        audioContextRef.current = null;
      }
      setIsRecording(false);
    } else {
      try {
        setAnalysisResult(null);
        
        wsRef.current = connectWebSocket((data) => {
          setAnalysisResult(data);
        });

        if (!wsRef.current) {
          throw new Error('Failed to connect WebSocket');
        }

        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        
        audioContextRef.current = new AudioContext({ sampleRate: 22050 });
        const source = audioContextRef.current.createMediaStreamSource(stream);
        const processor = audioContextRef.current.createScriptProcessor(4096, 1, 1);
        
        source.connect(processor);
        processor.connect(audioContextRef.current.destination);

        let audioBuffer: number[] = [];
        const CHUNK_SIZE = 22050 * 2;

        processor.onaudioprocess = (e) => {
          const inputData = e.inputBuffer.getChannelData(0);
          audioBuffer.push(...Array.from(inputData));

          if (audioBuffer.length >= CHUNK_SIZE) {
            if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
              wsRef.current.send(JSON.stringify(audioBuffer.slice(0, CHUNK_SIZE)));
            }
            audioBuffer = audioBuffer.slice(CHUNK_SIZE);
          }
        };

        setIsRecording(true);
      } catch (error) {
        console.error('Failed to start recording:', error);
        setAnalysisResult({
          status: 'error',
          message: 'Failed to access microphone. Please check permissions.'
        });
      }
    }
  };

  if (!mode) {
    return (
      <div className="analyze-page">
        <div className="analyze-background">
          <div className="waveform-container">
            {[...Array(20)].map((_, i) => (
              <div key={i} className={`waveform-bar bar-${i + 1}`}></div>
            ))}
          </div>
        </div>

        <div className="analyze-container">
          <button className="back-button" onClick={onBack}>
            <ArrowLeft />
          </button>

          <div className="mode-selector">
            <div className="selector-header">
              <Engine />
              <h1>Select Analysis Mode</h1>
              <p>Choose how you want to analyze your vehicle's audio</p>
            </div>

            <div className="mode-options">
              <button
                className="mode-option"
                onClick={() => setMode('live')}
                disabled={!isBackendConnected}
              >
                <div className="mode-icon live-icon">
                  <Mic />
                  <div className="pulse-ring"></div>
                </div>
                <h3>Live Analysis</h3>
                <p>Real-time engine sound analysis through microphone</p>
                <div className="mode-glow live-glow"></div>
              </button>

              <button
                className="mode-option"
                onClick={() => setMode('upload')}
                disabled={!isBackendConnected}
              >
                <div className="mode-icon upload-icon">
                  <Upload />
                </div>
                <h3>File Upload</h3>
                <p>Analyze pre-recorded MP3 or WAV audio files</p>
                <div className="mode-glow upload-glow"></div>
              </button>
            </div>

            {!isBackendConnected && (
              <div className="connection-warning">
                <AlertCircle />
                <span>Backend connection required for analysis</span>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="analyze-page">
      <div className="analyze-background">
        <div className="analyzer-grid">
          {[...Array(16)].map((_, i) => (
            <div key={i} className={`analyzer-cell cell-${i + 1}`}>
              <Signal />
            </div>
          ))}
        </div>
      </div>

      <div className="analyze-container">
        <div className="analyze-header">
          <button className="back-button" onClick={() => setMode(null)}>
            <ArrowLeft />
          </button>
          
          <h1>{mode === 'live' ? 'Live Audio Analysis' : 'File Analysis'}</h1>
        </div>

        <div className="analyze-content">
          {mode === 'live' && (
            <div className="live-analysis">
              <div className="recording-interface">
                <div className={`recording-visualizer ${isRecording ? 'active' : ''}`}>
                  <div className="mic-container">
                    <Mic />
                    {isRecording && <div className="recording-pulse"></div>}
                  </div>
                </div>
                
                <button
                  className={`record-button ${isRecording ? 'recording' : ''}`}
                  onClick={toggleRecording}
                >
                  {isRecording ? <Pause /> : <Play />}
                  <span>{isRecording ? 'STOP RECORDING' : 'START RECORDING'}</span>
                </button>
                
                <p className="recording-status">
                  {isRecording ? 'Analyzing engine sound...' : 'Press to start live analysis'}
                </p>
              </div>
            </div>
          )}

          {mode === 'upload' && (
            <div className="upload-analysis">
              <div className="upload-area">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".mp3,.wav"
                  onChange={handleFileUpload}
                  style={{ display: 'none' }}
                />
                
                <div
                  className="upload-zone"
                  onClick={() => fileInputRef.current?.click()}
                >
                  <Upload />
                  <h3>Drop your audio file here</h3>
                  <p>Supports MP3 and WAV formats (max 30 seconds)</p>
                  <button className="upload-button">Select File</button>
                </div>
              </div>

              {uploadedFile && (
                <div className="file-info">
                  <div className="file-details">
                    <Signal />
                    <span>{uploadedFile.name}</span>
                    <span className="file-size">
                      {(uploadedFile.size / 1024 / 1024).toFixed(2)} MB
                    </span>
                  </div>
                  
                  <button
                    className="analyze-button"
                    onClick={handleAnalyzeFile}
                    disabled={isAnalyzing}
                  >
                    {isAnalyzing ? (
                      <>
                        <div className="spinner"></div>
                        <span>ANALYZING...</span>
                      </>
                    ) : (
                      <>
                        <Engine />
                        <span>ANALYZE AUDIO</span>
                      </>
                    )}
                  </button>
                </div>
              )}
            </div>
          )}

          {analysisResult && (
            <div className="results-section">
              {analysisResult.status === 'success' && analysisResult.result && (
                <>
                  <div className="detected-issue-card">
                    <div className="issue-header">
                      <Engine />
                      <h2>Detected Issue</h2>
                    </div>
                    <div className="issue-name-display">
                      {analysisResult.result.detected_issue}
                    </div>
                    <div className="issue-indicator">
                      <div className="indicator-pulse"></div>
                    </div>
                  </div>

                  <div className="confidence-visualization">
                    <h3 className="viz-title">Confidence Distribution</h3>
                    
                    <div className="pie-chart-container">
                      <PieChart scores={analysisResult.result.confidence_scores} />
                    </div>

                    <div className="legend-container">
                      {Object.entries(analysisResult.result.confidence_scores)
                        .sort(([, a], [, b]) => b - a)
                        .map(([issue, confidence], index) => (
                          <div key={issue} className="legend-item" style={{ animationDelay: `${index * 0.1}s` }}>
                            <div 
                              className="legend-color"
                              style={{ background: getPieColor(index, Object.keys(analysisResult.result.confidence_scores).length) }}
                            ></div>
                            <span className="legend-label">{issue}</span>
                            <div className="confidence-badge">{confidence.toFixed(1)}%</div>
                          </div>
                        ))}
                    </div>
                  </div>
                </>
              )}
              
              {analysisResult.status === 'error' && (
                <div className="error-result">
                  <AlertCircle />
                  <p>{analysisResult.message}</p>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      <style>{`
        .detected-issue-card {
          background: linear-gradient(135deg, #1a1a1a 0%, #2a2a2a 100%);
          border: 2px solid #ff6b6b;
          border-radius: 1rem;
          padding: 2rem;
          margin-bottom: 2rem;
          position: relative;
          overflow: hidden;
          animation: slideIn 0.6s ease-out;
        }

        @keyframes slideIn {
          from {
            opacity: 0;
            transform: translateY(-20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        .issue-header {
          display: flex;
          align-items: center;
          gap: 0.75rem;
          margin-bottom: 1rem;
        }

        .issue-header svg {
          width: 24px;
          height: 24px;
          color: #ff6b6b;
        }

        .issue-header h2 {
          font-size: 1.2rem;
          color: #999;
          margin: 0;
          text-transform: uppercase;
          letter-spacing: 1px;
        }

        .issue-name-display {
          font-size: 2.5rem;
          font-weight: 800;
          color: #fff;
          text-align: center;
          margin: 1.5rem 0;
          text-transform: uppercase;
          letter-spacing: 2px;
          text-shadow: 0 0 20px rgba(255, 107, 107, 0.5);
          animation: pulse 2s ease-in-out infinite;
        }

        @keyframes pulse {
          0%, 100% {
            opacity: 1;
          }
          50% {
            opacity: 0.8;
          }
        }

        .issue-indicator {
          display: flex;
          justify-content: center;
          margin-top: 1rem;
        }

        .indicator-pulse {
          width: 12px;
          height: 12px;
          background: #ff6b6b;
          border-radius: 50%;
          position: relative;
          animation: pulseRing 2s ease-out infinite;
        }

        @keyframes pulseRing {
          0% {
            box-shadow: 0 0 0 0 rgba(255, 107, 107, 0.7);
          }
          70% {
            box-shadow: 0 0 0 20px rgba(255, 107, 107, 0);
          }
          100% {
            box-shadow: 0 0 0 0 rgba(255, 107, 107, 0);
          }
        }

        .confidence-visualization {
          background: linear-gradient(135deg, #1e1e1e 0%, #252525 100%);
          border-radius: 1rem;
          padding: 2rem;
          animation: slideIn 0.6s ease-out 0.2s both;
        }

        .viz-title {
          font-size: 1.5rem;
          color: #fff;
          margin: 0 0 2rem 0;
          text-align: center;
          text-transform: uppercase;
          letter-spacing: 2px;
        }

        .pie-chart-container {
          display: flex;
          justify-content: center;
          margin: 2rem 0;
        }

        .pie-chart {
          width: 100%;
          max-width: 400px;
          height: auto;
          filter: drop-shadow(0 10px 30px rgba(0, 0, 0, 0.5));
        }

        .pie-slice {
          cursor: pointer;
          transition: transform 0.3s ease, filter 0.3s ease;
        }

        .pie-slice:hover {
          transform: scale(1.05);
          filter: brightness(1.2);
        }

        @keyframes fadeIn {
          from {
            opacity: 0;
            transform: scale(0.8);
          }
          to {
            opacity: 1;
            transform: scale(1);
          }
        }

        .pie-center {
          transition: r 0.3s ease;
        }

        .pie-center-text {
          font-family: inherit;
          letter-spacing: 1px;
        }

        .pie-center-value {
          font-family: inherit;
          animation: countUp 2s ease-out;
        }

        @keyframes countUp {
          from {
            opacity: 0;
            transform: translateY(10px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        .legend-container {
          display: flex;
          flex-direction: column;
          gap: 1rem;
          margin-top: 2rem;
        }

        .legend-item {
          display: flex;
          align-items: center;
          gap: 1rem;
          padding: 0.75rem 1rem;
          background: #1a1a1a;
          border-radius: 0.5rem;
          opacity: 0;
          animation: slideInLeft 0.6s ease-out forwards;
          transition: transform 0.2s ease, box-shadow 0.2s ease;
        }

        .legend-item:hover {
          transform: translateX(5px);
          box-shadow: 0 4px 12px rgba(78, 205, 196, 0.2);
        }

        @keyframes slideInLeft {
          from {
            opacity: 0;
            transform: translateX(-20px);
          }
          to {
            opacity: 1;
            transform: translateX(0);
          }
        }

        .legend-color {
          width: 24px;
          height: 24px;
          border-radius: 4px;
          flex-shrink: 0;
          box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
        }

        .legend-label {
          flex: 1;
          color: #ccc;
          font-weight: 600;
          font-size: 0.95rem;
        }

        .confidence-badge {
          background: linear-gradient(135deg, #2a2a2a 0%, #1a1a1a 100%);
          color: #4ecdc4;
          font-weight: 700;
          font-size: 1rem;
          padding: 0.4rem 0.8rem;
          border-radius: 20px;
          border: 1px solid #4ecdc4;
          min-width: 60px;
          text-align: center;
          box-shadow: 0 0 10px rgba(78, 205, 196, 0.3);
        }

        .center-icon {
          animation: pulse 2s ease-in-out infinite;
        }

        @keyframes pulse {
          0%, 100% {
            opacity: 1;
          }
          50% {
            opacity: 0.7;
          }
        }
      `}</style>
    </div>
  );
};

export default AnalyzePage;
