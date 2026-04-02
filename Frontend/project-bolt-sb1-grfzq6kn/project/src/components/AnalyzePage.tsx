import React, { useState, useRef, useEffect } from 'react';
import { ArrowLeft, Mic, Upload, Signal, Engine, Pause, AlertCircle, Wrench, Phone, MapPin, CheckCircle } from './icons/CustomIcons';
import { uploadAudio, AnalyzeResult, connectWebSocket, getDIYSolution, getRoadsideAssistance, DIYSolution, RoadsideAssistance } from '../services/api';

interface AnalyzePageProps {
  onBack: () => void;
  isBackendConnected: boolean;
}

type AnalysisMode = 'live' | 'upload';
type ViewStage = 'mode-select' | 'analyzing' | 'result' | 'diy' | 'service' | 'roadside';

const CAR_BRANDS = [
  "Maruti Suzuki", "Hyundai", "Tata Motors", "Mahindra", "Honda",
  "Toyota", "Ford", "Volkswagen", "Renault", "Nissan",
  "Skoda", "MG Motors", "Kia", "Other"
];

const AnalyzePage: React.FC<AnalyzePageProps> = ({ onBack, isBackendConnected }) => {
  const [mode, setMode] = useState<AnalysisMode | null>(null);
  const [viewStage, setViewStage] = useState<ViewStage>('mode-select');
  const [isRecording, setIsRecording] = useState(false);
  const [uploadedFile, setUploadedFile] = useState<File | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysisResult, setAnalysisResult] = useState<AnalyzeResult | null>(null);
  const [diyStep, setDiyStep] = useState<number>(0);
  const [selectedBrand, setSelectedBrand] = useState<string>('');
  const [userLocation, setUserLocation] = useState<{lat: number; lng: number} | null>(null);
  const [diySolution, setDiySolution] = useState<DIYSolution | null>(null);
  const [roadsideData, setRoadsideData] = useState<RoadsideAssistance | null>(null);
  const [nearbyServices, setNearbyServices] = useState<any[]>([]);
  
  const fileInputRef = useRef<HTMLInputElement>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const sourceRef = useRef<MediaStreamAudioSourceNode | null>(null);
  const processorRef = useRef<ScriptProcessorNode | null>(null);

  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setUserLocation({
            lat: position.coords.latitude,
            lng: position.coords.longitude
          });
        },
        (error) => console.error('Location error:', error)
      );
    }
  }, []);

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
    setViewStage('analyzing');
    
    try {
      const result = await uploadAudio(uploadedFile);
      console.log('Analysis result:', result);
      setAnalysisResult(result);
      
      // Wait a moment for UI update, then move to result
      setTimeout(() => {
        if (result.status === 'success' && result.result) {
          setViewStage('result');
        } else {
          alert(result.message || 'Analysis failed');
          setViewStage('mode-select');
        }
        setIsAnalyzing(false);
      }, 1000);
      
    } catch (error) {
      console.error('Analysis failed:', error);
      setAnalysisResult({
        status: 'error',
        message: 'Analysis failed. Please try again.'
      });
      alert('Analysis failed. Please try again.');
      setViewStage('mode-select');
      setIsAnalyzing(false);
    }
  };

  const toggleRecording = async () => {
    if (isRecording) {
      // Stop recording
      if (processorRef.current) {
        processorRef.current.disconnect();
        processorRef.current = null;
      }
      if (sourceRef.current) {
        sourceRef.current.disconnect();
        sourceRef.current = null;
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
      setViewStage('mode-select');
    } else {
      // Start recording
      try {
        setAnalysisResult(null);
        
        const ws = connectWebSocket((data) => {
          console.log('WebSocket data received:', data);
          setAnalysisResult(data);
          if (data.status === 'success' && data.result) {
            setViewStage('result');
            setIsRecording(false);
          }
        });

        if (!ws) {
          throw new Error('Failed to connect WebSocket');
        }
        wsRef.current = ws;

        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        
        audioContextRef.current = new AudioContext({ sampleRate: 22050 });
        sourceRef.current = audioContextRef.current.createMediaStreamSource(stream);
        processorRef.current = audioContextRef.current.createScriptProcessor(4096, 1, 1);
        
        sourceRef.current.connect(processorRef.current);
        processorRef.current.connect(audioContextRef.current.destination);

        let audioBuffer: number[] = [];
        const CHUNK_SIZE = 22050 * 2;

        processorRef.current.onaudioprocess = (e) => {
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
        alert('Failed to access microphone. Please check permissions.');
        setViewStage('mode-select');
      }
    }
  };

  const handleViewDIY = async () => {
    if (!analysisResult?.result?.detected_issue_key) return;
    
    const response = await getDIYSolution(analysisResult.result.detected_issue_key);
    if (response.status === 'success' && response.solution) {
      setDiySolution(response.solution);
      setViewStage('diy');
      setDiyStep(0);
    }
  };

  const handleFindService = () => {
    setViewStage('service');
    fetchNearbyServices();
  };

  const handleRoadsideAssistance = async () => {
    const data = await getRoadsideAssistance('India', selectedBrand || undefined);
    setRoadsideData(data);
    setViewStage('roadside');
  };

  const fetchNearbyServices = async () => {
    if (!userLocation) {
      console.log('Location not available');
      // Fallback to generic Thiruvananthapuram location
      setUserLocation({ lat: 8.5241, lng: 76.9366 });
    }
    
    const query = selectedBrand 
      ? `${selectedBrand} service center near me`
      : 'car service center near me';
    
    try {
      // Using Overpass API (OpenStreetMap) - Free, no API key needed
      const overpassQuery = `
        [out:json];
        (
          node["shop"="car_repair"](around:5000,${userLocation?.lat || 8.5241},${userLocation?.lng || 76.9366});
          way["shop"="car_repair"](around:5000,${userLocation?.lat || 8.5241},${userLocation?.lng || 76.9366});
        );
        out body;
      `;
      
      const response = await fetch('https://overpass-api.de/api/interpreter', {
        method: 'POST',
        body: 'data=' + encodeURIComponent(overpassQuery)
      });
      
      if (response.ok) {
        const data = await response.json();
        const services = data.elements.map((element: any) => ({
          displayName: { text: element.tags?.name || 'Car Service Center' },
          formattedAddress: element.tags?.['addr:street'] 
            ? `${element.tags['addr:street']}, ${element.tags['addr:city'] || 'Thiruvananthapuram'}`
            : 'Thiruvananthapuram, Kerala',
          rating: null,
          internationalPhoneNumber: element.tags?.phone || null
        }));
        
        // If OSM doesn't return results, use fallback data
        if (services.length === 0) {
          setNearbyServices(getFallbackServiceCenters());
        } else {
          setNearbyServices(services.slice(0, 10)); // Limit to 10 results
        }
      } else {
        setNearbyServices(getFallbackServiceCenters());
      }
    } catch (error) {
      console.error('Service search failed:', error);
      setNearbyServices(getFallbackServiceCenters());
    }
  };

  const getFallbackServiceCenters = () => {
    return [
      {
        displayName: { text: 'Popular Motors Service Center' },
        formattedAddress: 'Karamana, Thiruvananthapuram, Kerala 695002',
        rating: 4.3,
        internationalPhoneNumber: '+91-471-2345678'
      },
      {
        displayName: { text: 'Auto Care Service Station' },
        formattedAddress: 'Pattom, Thiruvananthapuram, Kerala 695004',
        rating: 4.1,
        internationalPhoneNumber: '+91-471-2456789'
      },
      {
        displayName: { text: 'Express Car Service' },
        formattedAddress: 'Vellayambalam, Thiruvananthapuram, Kerala 695010',
        rating: 4.5,
        internationalPhoneNumber: '+91-471-2567890'
      },
      {
        displayName: { text: 'City Auto Workshop' },
        formattedAddress: 'Vazhuthacaud, Thiruvananthapuram, Kerala 695014',
        rating: 4.0,
        internationalPhoneNumber: '+91-471-2678901'
      },
      {
        displayName: { text: 'Premium Car Care' },
        formattedAddress: 'Statue, Thiruvananthapuram, Kerala 695001',
        rating: 4.4,
        internationalPhoneNumber: '+91-471-2789012'
      }
    ];
  };

  if (viewStage === 'mode-select') {
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
                onClick={() => {
                  setMode('live');
                  setViewStage('analyzing');
                  // Auto-start recording after a brief delay
                  setTimeout(() => toggleRecording(), 500);
                }}
                disabled={!isBackendConnected}
              >
                <div className="mode-icon">
                  <Mic />
                </div>
                <h3>Live Recording</h3>
                <p>Record engine sounds in real-time</p>
                <div className="mode-features">
                  <div className="feature">✓ Real-time analysis</div>
                  <div className="feature">✓ Continuous monitoring</div>
                  <div className="feature">✓ Instant results</div>
                </div>
              </button>

              <button
                className="mode-option"
                onClick={() => {
                  setMode('upload');
                  fileInputRef.current?.click();
                }}
                disabled={!isBackendConnected}
              >
                <div className="mode-icon">
                  <Upload />
                </div>
                <h3>Upload Audio</h3>
                <p>Analyze pre-recorded audio files</p>
                <div className="mode-features">
                  <div className="feature">✓ Upload .wav, .mp3, .m4a</div>
                  <div className="feature">✓ Detailed analysis</div>
                  <div className="feature">✓ Save results</div>
                </div>
              </button>

              <input
                ref={fileInputRef}
                type="file"
                accept="audio/*"
                onChange={handleFileUpload}
                style={{ display: 'none' }}
              />
            </div>

            {uploadedFile && (
              <div className="upload-preview">
                <div className="file-info">
                  <Signal />
                  <span className="file-name">{uploadedFile.name}</span>
                  <span className="file-size">
                    {(uploadedFile.size / 1024 / 1024).toFixed(2)} MB
                  </span>
                </div>
                <button 
                  className="analyze-btn" 
                  onClick={handleAnalyzeFile}
                  disabled={isAnalyzing || !isBackendConnected}
                >
                  {isAnalyzing ? 'Analyzing...' : 'Analyze Audio'}
                </button>
              </div>
            )}

            {!isBackendConnected && (
              <div className="connection-warning">
                <AlertCircle />
                <p>Backend connection lost. Please check if the server is running.</p>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  if (viewStage === 'analyzing') {
    return (
      <div className="analyze-page">
        <div className="analyze-background">
          <div className="waveform-active">
            {[...Array(30)].map((_, i) => (
              <div key={i} className={`wave-bar active-${i + 1}`}></div>
            ))}
          </div>
        </div>

        <div className="analyze-container">
          <button className="back-button" onClick={() => {
            if (mode === 'live' && isRecording) {
              toggleRecording();
            }
            setViewStage('mode-select');
            setIsAnalyzing(false);
          }}>
            <ArrowLeft />
          </button>

          <div className="analyzing-panel">
            <div className="analyzing-content">
              <div className="pulse-circle">
                <div className="pulse"></div>
                <div className="pulse-delay"></div>
                {mode === 'live' ? <Mic /> : <Signal />}
              </div>

              <h2>{mode === 'live' ? 'Recording & Analyzing...' : 'Analyzing Audio...'}</h2>
              <p>Processing audio through ML model</p>

              {mode === 'live' && (
                <button 
                  className={`record-btn ${isRecording ? 'recording' : ''}`}
                  onClick={toggleRecording}
                >
                  {isRecording ? (
                    <>
                      <Pause />
                      <span>Stop Recording</span>
                    </>
                  ) : (
                    <>
                      <Mic />
                      <span>Start Recording</span>
                    </>
                  )}
                </button>
              )}

              <div className="analysis-stats">
                <div className="stat">
                  <span className="stat-label">Sample Rate</span>
                  <span className="stat-value">22.05 kHz</span>
                </div>
                <div className="stat">
                  <span className="stat-label">Features</span>
                  <span className="stat-value">40 MFCC</span>
                </div>
                <div className="stat">
                  <span className="stat-label">Model</span>
                  <span className="stat-value">ML Classifier</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (viewStage === 'result' && analysisResult) {
    // Handle error state
    if (analysisResult.status === 'error' || !analysisResult.result) {
      return (
        <div className="analyze-page">
          <div className="analyze-background"></div>
          
          <div className="analyze-container">
            <button className="back-button" onClick={() => setViewStage('mode-select')}>
              <ArrowLeft />
            </button>

            <div className="error-panel">
              <AlertCircle />
              <h2>Analysis Failed</h2>
              <p>{analysisResult.message || 'Unable to analyze the audio. Please try again.'}</p>
              <button className="action-btn" onClick={() => setViewStage('mode-select')}>
                Try Again
              </button>
            </div>
          </div>
        </div>
      );
    }

    // Success state
    return (
      <div className="analyze-page">
        <div className="analyze-background"></div>
        
        <div className="analyze-container">
          <button className="back-button" onClick={() => setViewStage('mode-select')}>
            <ArrowLeft />
          </button>

          <div className="result-panel">
            <div className="detected-issue-card">
              <div className="issue-header">
                <AlertCircle />
                <h2>DETECTED ISSUE</h2>
              </div>
              <div className="issue-name-display">{analysisResult.result.detected_issue}</div>
              <div className="issue-indicator">
                <div className="indicator-pulse"></div>
              </div>
            </div>

            <div className="action-cards">
              <button className="action-card diy-card" onClick={handleViewDIY}>
                <Wrench />
                <h3>DIY Solutions</h3>
                <p>Try fixing it yourself first</p>
              </button>

              <button className="action-card service-card" onClick={handleFindService}>
                <MapPin />
                <h3>Find Service Center</h3>
                <p>Locate nearby professionals</p>
              </button>

              <button className="action-card roadside-card" onClick={handleRoadsideAssistance}>
                <Phone />
                <h3>Roadside Assistance</h3>
                <p>Get immediate help</p>
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (viewStage === 'diy' && diySolution) {
    return (
      <div className="analyze-page">
        <div className="analyze-background"></div>
        
        <div className="analyze-container">
          <button className="back-button" onClick={() => setViewStage('result')}>
            <ArrowLeft />
          </button>

          <div className="diy-panel">
            <div className="diy-header">
              <Wrench />
              <h1>DIY Solution: {diySolution.issue}</h1>
              <div className={`severity-badge ${diySolution.severity}`}>
                {diySolution.severity.toUpperCase()}
              </div>
            </div>

            {!diySolution.diy_possible ? (
              <div className="diy-warning">
                <AlertCircle />
                <h3>Professional Service Recommended</h3>
                <p>{diySolution.warning}</p>
                <button className="action-btn" onClick={handleFindService}>
                  Find Service Center
                </button>
              </div>
            ) : (
              <>
                <div className="diy-info">
                  <div className="info-item">
                    <strong>Estimated Time:</strong> {diySolution.estimated_time}
                  </div>
                  <div className="info-item">
                    <strong>Tools Needed:</strong> {diySolution.tools_needed.join(', ')}
                  </div>
                </div>

                <div className="diy-steps">
                  <h3>Steps to Fix</h3>
                  {diySolution.steps.map((step, index) => (
                    <div 
                      key={index} 
                      className={`diy-step ${index <= diyStep ? 'completed' : ''}`}
                      onClick={() => setDiyStep(index)}
                    >
                      <div className="step-number">{index + 1}</div>
                      <div className="step-content">{step}</div>
                      {index <= diyStep && <CheckCircle />}
                    </div>
                  ))}
                </div>

                <div className="diy-warning-box">
                  <AlertCircle />
                  <p>{diySolution.warning}</p>
                </div>

                <button className="action-btn secondary" onClick={handleFindService}>
                  Still Need Help? Find Service Center
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    );
  }

  if (viewStage === 'service') {
    return (
      <div className="analyze-page">
        <div className="analyze-background"></div>
        
        <div className="analyze-container">
          <button className="back-button" onClick={() => setViewStage('result')}>
            <ArrowLeft />
          </button>

          <div className="service-panel">
            <div className="service-header">
              <MapPin />
              <h1>Nearby Service Centers</h1>
            </div>

            <div className="brand-selector">
              <label>Select Your Car Brand:</label>
              <select value={selectedBrand} onChange={(e) => {
                setSelectedBrand(e.target.value);
                fetchNearbyServices();
              }}>
                <option value="">All Brands</option>
                {CAR_BRANDS.map(brand => (
                  <option key={brand} value={brand}>{brand}</option>
                ))}
              </select>
            </div>

            <div className="service-list">
              {nearbyServices.length > 0 ? (
                nearbyServices.map((service, index) => (
                  <div key={index} className="service-card-item">
                    <div className="service-name">{service.displayName?.text || 'Service Center'}</div>
                    <div className="service-address">{service.formattedAddress}</div>
                    {service.rating && (
                      <div className="service-rating">⭐ {service.rating}</div>
                    )}
                    {service.internationalPhoneNumber && (
                      <a href={`tel:${service.internationalPhoneNumber}`} className="service-phone">
                        <Phone /> {service.internationalPhoneNumber}
                      </a>
                    )}
                  </div>
                ))
              ) : (
                <div className="no-results">
                  <p>Loading service centers...</p>
                  <p className="help-text">Please wait while we fetch nearby locations</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (viewStage === 'roadside' && roadsideData) {
    return (
      <div className="analyze-page">
        <div className="analyze-background"></div>
        
        <div className="analyze-container">
          <button className="back-button" onClick={() => setViewStage('result')}>
            <ArrowLeft />
          </button>

          <div className="roadside-panel">
            <div className="roadside-header">
              <Phone />
              <h1>Roadside Assistance</h1>
            </div>

            <div className="brand-selector">
              <label>Your Car Brand:</label>
              <select value={selectedBrand} onChange={(e) => {
                setSelectedBrand(e.target.value);
                getRoadsideAssistance('India', e.target.value).then(setRoadsideData);
              }}>
                <option value="">Select Brand</option>
                {CAR_BRANDS.map(brand => (
                  <option key={brand} value={brand}>{brand}</option>
                ))}
              </select>
            </div>

            <div className="helpline-section">
              <h3>National Helplines</h3>
              {roadsideData.national_helplines.map((helpline, index) => (
                <a key={index} href={`tel:${helpline.number}`} className="helpline-card">
                  <Phone />
                  <div>
                    <div className="helpline-name">{helpline.name}</div>
                    <div className="helpline-number">{helpline.number}</div>
                  </div>
                </a>
              ))}
            </div>

            {roadsideData.brand_assistance && (
              <div className="helpline-section brand-section">
                <h3>{selectedBrand} Roadside Assistance</h3>
                <a href={`tel:${roadsideData.brand_assistance.number}`} className="helpline-card brand-card">
                  <Phone />
                  <div>
                    <div className="helpline-number">{roadsideData.brand_assistance.number}</div>
                    <div className="helpline-availability">{roadsideData.brand_assistance.availability}</div>
                  </div>
                </a>
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }

  return null;
};

export default AnalyzePage;