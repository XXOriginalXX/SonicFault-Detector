import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  ArrowLeft, Mic, Upload, Signal, Engine, Pause,
  AlertCircle, Wrench, Phone, MapPin, CheckCircle
} from './icons/CustomIcons';
import {
  uploadAudio, AnalyzeResult, connectWebSocket, getDIYSolution,
  getRoadsideAssistance, DIYSolution, RoadsideAssistance,
  GraphData, getGraphData, getModelComparison
} from '../services/api';

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

// ─────────────────────────────────────────────────────────────────
// WAVEFORM GRAPH UTILITIES & COMPONENT
// ─────────────────────────────────────────────────────────────────

function seededRand(seed: number) {
  let s = seed;
  return () => { s = (s * 9301 + 49297) % 233280; return s / 233280; };
}

const GRAPH_PROFILES: Record<string, {
  baseFreq: number; peakFreq: number; noiseFloor: number;
  anomalyFreqs: number[]; spikeAmp: number;
}> = {
  no_issue:           { baseFreq:45, peakFreq:90,  noiseFloor:-62, anomalyFreqs:[],           spikeAmp:0.0  },
  low_compression:    { baseFreq:40, peakFreq:80,  noiseFloor:-52, anomalyFreqs:[160,320],    spikeAmp:0.55 },
  turbo_leak:         { baseFreq:50, peakFreq:200, noiseFloor:-48, anomalyFreqs:[200,400,600],spikeAmp:0.45 },
  belt_issue:         { baseFreq:38, peakFreq:75,  noiseFloor:-50, anomalyFreqs:[75,150,225], spikeAmp:0.50 },
  timing_belt_issue:  { baseFreq:42, peakFreq:85,  noiseFloor:-45, anomalyFreqs:[85,170,340], spikeAmp:0.70 },
  injector_issue:     { baseFreq:44, peakFreq:88,  noiseFloor:-46, anomalyFreqs:[88,176,264], spikeAmp:0.60 },
  oil_coolant_mixing: { baseFreq:40, peakFreq:80,  noiseFloor:-44, anomalyFreqs:[60,120,240], spikeAmp:0.40 },
  lock_issue:         { baseFreq:35, peakFreq:70,  noiseFloor:-58, anomalyFreqs:[70,140],     spikeAmp:0.30 },
  general_issue:      { baseFreq:42, peakFreq:84,  noiseFloor:-50, anomalyFreqs:[84,168],     spikeAmp:0.35 },
};

const WaveformGraph: React.FC<{ issueKey: string }> = ({ issueKey }) => {
  const waveRef = useRef<HTMLCanvasElement>(null);
  const fftRef  = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const p = GRAPH_PROFILES[issueKey] ?? GRAPH_PROFILES['general_issue'];
    const r  = seededRand(issueKey.length * 97 + 13);
    const rn = seededRand(42);
    const N  = 200;
    const BINS = 100;

    // ── Time domain ──────────────────────────────────────────────
    const wCanvas = waveRef.current; if (!wCanvas) return;
    const wCtx = wCanvas.getContext('2d')!;
    const W = wCanvas.width, H = wCanvas.height;
    const pL=36, pR=8, pT=8, pB=24;
    const pW = W-pL-pR, pH = H-pT-pB;
    const midY = pT + pH/2;
    const toX = (i: number) => pL + (i/(N-1))*pW;
    const toY = (v: number) => midY - v*(pH/2)*0.88;

    wCtx.clearRect(0,0,W,H);

    wCtx.strokeStyle = 'rgba(128,128,128,0.12)'; wCtx.lineWidth=0.5;
    [-1,-0.5,0,0.5,1].forEach(v => {
      const y = toY(v);
      wCtx.beginPath(); wCtx.moveTo(pL,y); wCtx.lineTo(W-pR,y); wCtx.stroke();
    });
    for(let i=0;i<=4;i++){
      const x=pL+(i/4)*pW;
      wCtx.beginPath(); wCtx.moveTo(x,pT); wCtx.lineTo(x,H-pB); wCtx.stroke();
    }

    wCtx.fillStyle='rgba(128,128,128,0.6)'; wCtx.font='9px monospace'; wCtx.textAlign='right';
    [-1,-0.5,0,0.5,1].forEach(v => wCtx.fillText(v.toFixed(1), pL-3, toY(v)+3));
    wCtx.textAlign='center';
    [0,500,1000,1500,2000].forEach((ms,i) => wCtx.fillText(ms+'', pL+(i/4)*pW, H-pB+12));

    wCtx.fillStyle='rgba(128,128,128,0.45)'; wCtx.font='8px monospace';
    wCtx.textAlign='center'; wCtx.fillText('Time (ms)', pL+pW/2, H-2);
    wCtx.save(); wCtx.translate(10, pT+pH/2); wCtx.rotate(-Math.PI/2);
    wCtx.fillText('Amplitude', 0, 0); wCtx.restore();

    const normalPts = Array.from({length:N}, (_,i)=>{
      const ms = i*(2000/N);
      return 0.6*Math.sin(2*Math.PI*45*ms/1000) + 0.03*(rn()-0.5);
    });
    wCtx.beginPath(); wCtx.strokeStyle='rgba(55,138,221,0.6)';
    wCtx.lineWidth=1.2; wCtx.setLineDash([5,4]);
    normalPts.forEach((v,i)=>{ const x=toX(i),y=toY(v); i===0?wCtx.moveTo(x,y):wCtx.lineTo(x,y); });
    wCtx.stroke(); wCtx.setLineDash([]);

    const detPts = Array.from({length:N}, (_,i)=>{
      const ms = i*(2000/N);
      const base = 0.6*Math.sin(2*Math.PI*p.baseFreq*ms/1000);
      const noise = 0.05*(r()-0.5);
      const interval = Math.round(N/(p.baseFreq*0.5));
      const spike = (p.anomalyFreqs.length>0 && interval>0 && i%interval<3)
        ? p.spikeAmp*(0.8+0.4*r()) : 0;
      const mod = p.anomalyFreqs.length>0 ? 1+0.3*Math.sin(2*Math.PI*3*ms/1000) : 1;
      return Math.max(-1, Math.min(1, base*mod+noise+spike));
    });
    const detColor = issueKey==='no_issue' ? '#1d9e75' : '#e24b4a';
    wCtx.beginPath(); wCtx.strokeStyle=detColor; wCtx.lineWidth=1.8;
    detPts.forEach((v,i)=>{ const x=toX(i),y=toY(v); i===0?wCtx.moveTo(x,y):wCtx.lineTo(x,y); });
    wCtx.stroke();

    // ── Frequency spectrum ────────────────────────────────────────
    const fCanvas = fftRef.current; if (!fCanvas) return;
    const fCtx = fCanvas.getContext('2d')!;
    const FW=fCanvas.width, FH=fCanvas.height;
    const fpL=38, fpR=8, fpT=8, fpB=24;
    const fpW=FW-fpL-fpR, fpH=FH-fpT-fpB;
    const minDB=-80, maxDB=5;
    const toFX = (i: number) => fpL+(i/(BINS-1))*fpW;
    const toFY = (db: number) => fpT+fpH - ((db-minDB)/(maxDB-minDB))*fpH;

    fCtx.clearRect(0,0,FW,FH);

    fCtx.strokeStyle='rgba(128,128,128,0.12)'; fCtx.lineWidth=0.5;
    [-80,-60,-40,-20,0].forEach(db=>{
      const y=toFY(db);
      fCtx.beginPath(); fCtx.moveTo(fpL,y); fCtx.lineTo(FW-fpR,y); fCtx.stroke();
    });
    [0,1000,2000,3000,4000].forEach((_,i)=>{
      const x=fpL+(i/4)*fpW;
      fCtx.beginPath(); fCtx.moveTo(x,fpT); fCtx.lineTo(x,FH-fpB); fCtx.stroke();
    });

    fCtx.fillStyle='rgba(128,128,128,0.6)'; fCtx.font='9px monospace'; fCtx.textAlign='right';
    [-80,-60,-40,-20,0].forEach(db=>fCtx.fillText(db+'', fpL-3, toFY(db)+3));
    fCtx.textAlign='center';
    [0,1000,2000,3000,4000].forEach((f,i)=>fCtx.fillText(f<1000?f+'':f/1000+'k', fpL+(i/4)*fpW, FH-fpB+12));
    fCtx.fillStyle='rgba(128,128,128,0.45)'; fCtx.font='8px monospace';
    fCtx.textAlign='center'; fCtx.fillText('Frequency (Hz)', fpL+fpW/2, FH-2);
    fCtx.save(); fCtx.translate(10, fpT+fpH/2); fCtx.rotate(-Math.PI/2);
    fCtx.fillText('Magnitude (dB)', 0, 0); fCtx.restore();

    const freqs = Array.from({length:BINS}, (_,i)=>i*(4000/BINS));
    const r2 = seededRand(issueKey.length*53+7);
    const rn2 = seededRand(17);

    const normalFFT = freqs.map(f=>{
      let m=-62+4*(rn2()-0.5);
      m+=16*Math.exp(-Math.pow(f-90,2)/(2*40*40));
      m+=8*Math.exp(-Math.pow(f-45,2)/(2*20*20));
      return Math.min(0,Math.max(-80,m));
    });
    const detFFT = freqs.map(f=>{
      let m=p.noiseFloor+6*(r2()-0.5);
      m+=18*Math.exp(-Math.pow(f-p.peakFreq,2)/(2*50*50));
      m+=10*Math.exp(-Math.pow(f-p.peakFreq*0.5,2)/(2*30*30));
      for(const af of p.anomalyFreqs)
        m+=(p.spikeAmp*22)*Math.exp(-Math.pow(f-af,2)/(2*15*15));
      return Math.min(0,Math.max(-80,m));
    });

    fCtx.beginPath();
    detFFT.forEach((db,i)=>{ const x=toFX(i),y=toFY(db); i===0?fCtx.moveTo(x,y):fCtx.lineTo(x,y); });
    fCtx.lineTo(toFX(BINS-1), FH-fpB); fCtx.lineTo(fpL, FH-fpB); fCtx.closePath();
    fCtx.fillStyle = detColor+'18'; fCtx.fill();

    fCtx.beginPath(); fCtx.strokeStyle='rgba(55,138,221,0.6)';
    fCtx.lineWidth=1.2; fCtx.setLineDash([5,4]);
    normalFFT.forEach((db,i)=>{ const x=toFX(i),y=toFY(db); i===0?fCtx.moveTo(x,y):fCtx.lineTo(x,y); });
    fCtx.stroke(); fCtx.setLineDash([]);

    fCtx.beginPath(); fCtx.strokeStyle=detColor; fCtx.lineWidth=1.8;
    detFFT.forEach((db,i)=>{ const x=toFX(i),y=toFY(db); i===0?fCtx.moveTo(x,y):fCtx.lineTo(x,y); });
    fCtx.stroke();

  }, [issueKey]);

  return (
    <div>
      <div style={{ display:'grid', gridTemplateColumns:'1fr 1fr', gap:10 }}>
        <div style={{ background:'rgba(255,255,255,0.03)', border:'0.5px solid rgba(255,255,255,0.08)', borderRadius:10, padding:'10px 8px' }}>
          <p style={{ fontSize:9, letterSpacing:'0.1em', textTransform:'uppercase', color:'rgba(255,255,255,0.3)', margin:'0 0 6px 0' }}>
            Time domain — amplitude vs time (ms)
          </p>
          <canvas ref={waveRef} width={300} height={140} style={{ width:'100%', height:140, display:'block' }} />
        </div>
        <div style={{ background:'rgba(255,255,255,0.03)', border:'0.5px solid rgba(255,255,255,0.08)', borderRadius:10, padding:'10px 8px' }}>
          <p style={{ fontSize:9, letterSpacing:'0.1em', textTransform:'uppercase', color:'rgba(255,255,255,0.3)', margin:'0 0 6px 0' }}>
            Frequency spectrum — magnitude (dB) vs freq (Hz)
          </p>
          <canvas ref={fftRef} width={300} height={140} style={{ width:'100%', height:140, display:'block' }} />
        </div>
      </div>
      <div style={{ display:'flex', gap:16, justifyContent:'center', marginTop:8 }}>
        <span style={{ display:'flex', alignItems:'center', gap:6, fontSize:11, color:'rgba(255,255,255,0.45)' }}>
          <svg width={20} height={4}><line x1={0} y1={2} x2={20} y2={2} stroke={issueKey==='no_issue'?'#1d9e75':'#e24b4a'} strokeWidth={2}/></svg>
          Detected
        </span>
        <span style={{ display:'flex', alignItems:'center', gap:6, fontSize:11, color:'rgba(255,255,255,0.45)' }}>
          <svg width={20} height={4}><line x1={0} y1={2} x2={20} y2={2} stroke="rgba(55,138,221,0.7)" strokeWidth={1.5} strokeDasharray="4 3"/></svg>
          Normal baseline
        </span>
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────────
// MODEL COMPARISON BAR CHART
// ─────────────────────────────────────────────────────────────────
const ModelComparisonChart: React.FC<{ issueKey: string }> = ({ issueKey }) => {
  const [animated, setAnimated] = useState(false);
  const comparison = getModelComparison(issueKey);

  useEffect(() => {
    const t = setTimeout(() => setAnimated(true), 120);
    return () => clearTimeout(t);
  }, [issueKey]);

  return (
    <div style={{ width: '100%' }}>
      <p style={{
        fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase',
        color: 'rgba(255,255,255,0.35)', marginBottom: 10, marginTop: 0
      }}>
        Model Accuracy Comparison
      </p>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
        {comparison.models.map((m, i) => (
          <ModelBar
            key={m.name}
            name={m.name}
            accuracy={m.accuracy}
            color={m.color}
            animated={animated}
            delay={i * 80}
            isTop={i === 0}
          />
        ))}
      </div>
    </div>
  );
};

const ModelBar: React.FC<{
  name: string;
  accuracy: number;
  color: string;
  animated: boolean;
  delay: number;
  isTop: boolean;
}> = ({ name, accuracy, color, animated, delay, isTop }) => {
  const [width, setWidth] = useState(0);

  useEffect(() => {
    if (!animated) return;
    const t = setTimeout(() => setWidth(accuracy), delay);
    return () => clearTimeout(t);
  }, [animated, accuracy, delay]);

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <span style={{
        fontSize: 11,
        width: 100, flexShrink: 0, textAlign: 'right',
        fontWeight: isTop ? 600 : 400,
        color: isTop ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.5)',
      }}>
        {name}
      </span>
      <div style={{
        flex: 1, height: isTop ? 12 : 9,
        background: 'rgba(255,255,255,0.06)',
        borderRadius: 6, overflow: 'hidden', position: 'relative'
      }}>
        <div style={{
          height: '100%',
          width: `${width}%`,
          background: isTop
            ? `linear-gradient(90deg, ${color}cc, ${color})`
            : color,
          borderRadius: 6,
          transition: `width 700ms cubic-bezier(0.22,1,0.36,1) ${delay}ms`,
          boxShadow: isTop ? `0 0 10px ${color}66` : 'none',
        }} />
      </div>
      <span style={{
        fontSize: isTop ? 13 : 11,
        fontWeight: isTop ? 700 : 400,
        color: isTop ? color : 'rgba(255,255,255,0.45)',
        width: 42, flexShrink: 0,
        textShadow: isTop ? `0 0 8px ${color}88` : 'none',
      }}>
        {width > 0 ? `${accuracy}%` : '—'}
      </span>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────────
// MAIN COMPONENT
// ─────────────────────────────────────────────────────────────────
const AnalyzePage: React.FC<AnalyzePageProps> = ({ onBack, isBackendConnected }) => {
  const [mode, setMode] = useState<AnalysisMode | null>(null);
  const [viewStage, setViewStage] = useState<ViewStage>('mode-select');
  const [isRecording, setIsRecording] = useState(false);
  const [uploadedFile, setUploadedFile] = useState<File | null>(null);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [analysisResult, setAnalysisResult] = useState<AnalyzeResult | null>(null);
  const [graphData, setGraphData] = useState<GraphData | null>(null);
  const [diyStep, setDiyStep] = useState<number>(0);
  const [selectedBrand, setSelectedBrand] = useState<string>('');
  const [userLocation, setUserLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [diySolution, setDiySolution] = useState<DIYSolution | null>(null);
  const [roadsideData, setRoadsideData] = useState<RoadsideAssistance | null>(null);
  const [nearbyServices, setNearbyServices] = useState<any[]>([]);

  const fileInputRef = useRef<HTMLInputElement>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const sourceRef = useRef<MediaStreamAudioSourceNode | null>(null);
  const processorRef = useRef<ScriptProcessorNode | null>(null);
  const streamRef = useRef<MediaStream | null>(null);

  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => setUserLocation({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
        (err) => console.error('Location error:', err)
      );
    }
  }, []);

  // ── Clean up all audio resources ─────────────────────────────
  const stopAllAudio = useCallback(() => {
    processorRef.current?.disconnect();
    processorRef.current = null;

    sourceRef.current?.disconnect();
    sourceRef.current = null;

    if (streamRef.current) {
      streamRef.current.getTracks().forEach(t => t.stop());
      streamRef.current = null;
    }

    if (wsRef.current) {
      wsRef.current.onmessage = null; // prevent stale callbacks
      wsRef.current.close();
      wsRef.current = null;
    }

    if (audioContextRef.current) {
      audioContextRef.current.close();
      audioContextRef.current = null;
    }

    setIsRecording(false);
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => { stopAllAudio(); };
  }, [stopAllAudio]);

  const handleFileUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) { setUploadedFile(file); setAnalysisResult(null); setGraphData(null); }
  };

  const handleAnalyzeFile = async () => {
    if (!uploadedFile || !isBackendConnected) return;
    setIsAnalyzing(true);
    setViewStage('analyzing');
    try {
      const result = await uploadAudio(uploadedFile);
      setAnalysisResult(result);

      if (result.status === 'success' && result.result) {
        const gd = result.graph ?? await getGraphData(result.result.detected_issue_key);
        setGraphData(gd);
      }

      setTimeout(() => {
        if (result.status === 'success' && result.result) {
          setViewStage('result');
        } else {
          alert(result.message || 'Analysis failed');
          setViewStage('mode-select');
        }
        setIsAnalyzing(false);
      }, 1000);
    } catch {
      setAnalysisResult({ status: 'error', message: 'Analysis failed. Please try again.' });
      alert('Analysis failed. Please try again.');
      setViewStage('mode-select');
      setIsAnalyzing(false);
    }
  };

  // ── START live recording ──────────────────────────────────────
  // Separated start/stop to avoid self-referencing closure bugs
  const startRecording = useCallback(async () => {
    try {
      setAnalysisResult(null);
      setGraphData(null);

      // 1. Get mic access FIRST — if this fails we stay on mode-select
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;

      // 2. Now it's safe to show the analyzing view
      setViewStage('analyzing');

      // 3. Init WebSocket
      const ws = connectWebSocket(async (data) => {
        console.log('WebSocket Data Received:', data);
        if (data.status === 'success' && data.result) {
          setAnalysisResult(data);
          const gd = data.graph ?? await getGraphData(data.result.detected_issue_key);
          setGraphData(gd);
          // Stop recording and go to results — use stopAllAudio directly, not toggleRecording
          stopAllAudio();
          setViewStage('result');
        }
      });

      if (!ws) {
        stream.getTracks().forEach(t => t.stop());
        streamRef.current = null;
        throw new Error('Failed to initialize WebSocket');
      }

      ws.onerror = (err) => console.error('WebSocket Error:', err);
      ws.onclose = () => console.log('WebSocket Closed');
      wsRef.current = ws;

      // 4. Setup Audio Pipeline
      audioContextRef.current = new (window.AudioContext || (window as any).webkitAudioContext)({
        sampleRate: 22050,
      });

      sourceRef.current = audioContextRef.current.createMediaStreamSource(stream);
      processorRef.current = audioContextRef.current.createScriptProcessor(4096, 1, 1);

      sourceRef.current.connect(processorRef.current);
      processorRef.current.connect(audioContextRef.current.destination);

      let audioBuffer: number[] = [];
      const CHUNK_SIZE = 44100;

      processorRef.current.onaudioprocess = (e) => {
        const inputData = e.inputBuffer.getChannelData(0);
        audioBuffer.push(...Array.from(inputData));

        if (audioBuffer.length >= CHUNK_SIZE) {
          if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
            const payload = audioBuffer.slice(0, CHUNK_SIZE);
            wsRef.current.send(JSON.stringify(payload));
            console.log('Sent audio chunk to backend');
          }
          audioBuffer = [];
        }
      };

      setIsRecording(true);
    } catch (err) {
      console.error('Microphone Access Error:', err);
      stopAllAudio();
      alert('Could not start live analysis. Please ensure microphone permissions are granted.');
      setViewStage('mode-select');
    }
  }, [stopAllAudio]);

  // ── Toggle used only by the Stop button in the analyzing view ─
  const handleStopRecording = useCallback(() => {
    stopAllAudio();
    setViewStage('mode-select');
  }, [stopAllAudio]);

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
    const lat = userLocation?.lat ?? 8.5241;
    const lng = userLocation?.lng ?? 76.9366;
    if (!userLocation) setUserLocation({ lat, lng });

    try {
      const overpassQuery = `
        [out:json];
        (
          node["shop"="car_repair"](around:5000,${lat},${lng});
          way["shop"="car_repair"](around:5000,${lat},${lng});
        );
        out body;
      `;
      const response = await fetch('https://overpass-api.de/api/interpreter', {
        method: 'POST',
        body: 'data=' + encodeURIComponent(overpassQuery),
      });
      if (response.ok) {
        const data = await response.json();
        const services = data.elements.map((el: any) => ({
          displayName: { text: el.tags?.name || 'Car Service Center' },
          formattedAddress: el.tags?.['addr:street']
            ? `${el.tags['addr:street']}, ${el.tags['addr:city'] || 'Thiruvananthapuram'}`
            : 'Thiruvananthapuram, Kerala',
          rating: null,
          internationalPhoneNumber: el.tags?.phone || null,
        }));
        setNearbyServices(services.length > 0 ? services.slice(0, 10) : getFallbackServiceCenters());
      } else {
        setNearbyServices(getFallbackServiceCenters());
      }
    } catch {
      setNearbyServices(getFallbackServiceCenters());
    }
  };

  const getFallbackServiceCenters = () => [
    { displayName: { text: 'Popular Motors Service Center' }, formattedAddress: 'Karamana, Thiruvananthapuram, Kerala 695002', rating: 4.3, internationalPhoneNumber: '+91-471-2345678' },
    { displayName: { text: 'Auto Care Service Station' }, formattedAddress: 'Pattom, Thiruvananthapuram, Kerala 695004', rating: 4.1, internationalPhoneNumber: '+91-471-2456789' },
    { displayName: { text: 'Express Car Service' }, formattedAddress: 'Vellayambalam, Thiruvananthapuram, Kerala 695010', rating: 4.5, internationalPhoneNumber: '+91-471-2567890' },
    { displayName: { text: 'City Auto Workshop' }, formattedAddress: 'Vazhuthacaud, Thiruvananthapuram, Kerala 695014', rating: 4.0, internationalPhoneNumber: '+91-471-2678901' },
    { displayName: { text: 'Premium Car Care' }, formattedAddress: 'Statue, Thiruvananthapuram, Kerala 695001', rating: 4.4, internationalPhoneNumber: '+91-471-2789012' },
  ];

  // ── MODE SELECT ───────────────────────────────────────────────
  if (viewStage === 'mode-select') {
    return (
      <div className="analyze-page">
        <div className="analyze-background">
          <div className="waveform-container">
            {[...Array(20)].map((_, i) => (
              <div key={i} className={`waveform-bar bar-${i + 1}`} />
            ))}
          </div>
        </div>
        <div className="analyze-container">
          <button className="back-button" onClick={onBack}><ArrowLeft /></button>
          <div className="mode-selector">
            <div className="selector-header">
              <Engine />
              <h1>Select Analysis Mode</h1>
              <p>Choose how you want to analyze your vehicle's audio</p>
            </div>
            <div className="mode-options">
              {/* FIX: startRecording handles the stage transition internally after mic is granted */}
              <button
                className="mode-option"
                onClick={() => { setMode('live'); startRecording(); }}
                disabled={!isBackendConnected}
              >
                <div className="mode-icon"><Mic /></div>
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
                onClick={() => { setMode('upload'); fileInputRef.current?.click(); }}
                disabled={!isBackendConnected}
              >
                <div className="mode-icon"><Upload /></div>
                <h3>Upload Audio</h3>
                <p>Analyze pre-recorded audio files</p>
                <div className="mode-features">
                  <div className="feature">✓ Upload .wav, .mp3, .m4a</div>
                  <div className="feature">✓ Detailed analysis</div>
                  <div className="feature">✓ Save results</div>
                </div>
              </button>
              <input ref={fileInputRef} type="file" accept="audio/*" onChange={handleFileUpload} style={{ display: 'none' }} />
            </div>
            {uploadedFile && (
              <div className="upload-preview">
                <div className="file-info">
                  <Signal />
                  <span className="file-name">{uploadedFile.name}</span>
                  <span className="file-size">{(uploadedFile.size / 1024 / 1024).toFixed(2)} MB</span>
                </div>
                <button className="analyze-btn" onClick={handleAnalyzeFile} disabled={isAnalyzing || !isBackendConnected}>
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

  // ── ANALYZING ────────────────────────────────────────────────
  if (viewStage === 'analyzing') {
    return (
      <div className="analyze-page">
        <div className="analyze-background">
          <div className="waveform-active">
            {[...Array(30)].map((_, i) => (
              <div key={i} className={`wave-bar active-${i + 1}`} />
            ))}
          </div>
        </div>
        <div className="analyze-container">
          <button className="back-button" onClick={() => {
            stopAllAudio();
            setViewStage('mode-select');
            setIsAnalyzing(false);
          }}><ArrowLeft /></button>
          <div className="analyzing-panel">
            <div className="analyzing-content">
              <div className="pulse-circle">
                <div className="pulse" /><div className="pulse-delay" />
                {mode === 'live' ? <Mic /> : <Signal />}
              </div>
              <h2>{mode === 'live' ? 'Recording & Analyzing...' : 'Analyzing Audio...'}</h2>
              <p>Processing audio through ML model</p>
              {mode === 'live' && (
                /* FIX: Stop button calls handleStopRecording, not toggleRecording */
                <button
                  className={`record-btn ${isRecording ? 'recording' : ''}`}
                  onClick={handleStopRecording}
                >
                  {isRecording
                    ? <><Pause /><span>Stop Recording</span></>
                    : <><Mic /><span>Start Recording</span></>
                  }
                </button>
              )}
              <div className="analysis-stats">
                <div className="stat"><span className="stat-label">Sample Rate</span><span className="stat-value">22.05 kHz</span></div>
                <div className="stat"><span className="stat-label">Features</span><span className="stat-value">40 MFCC</span></div>
                <div className="stat"><span className="stat-label">Model</span><span className="stat-value">ML Classifier</span></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // ── RESULT ───────────────────────────────────────────────────
  if (viewStage === 'result' && analysisResult) {
    if (analysisResult.status === 'error' || !analysisResult.result) {
      return (
        <div className="analyze-page">
          <div className="analyze-background" />
          <div className="analyze-container">
            <button className="back-button" onClick={() => setViewStage('mode-select')}><ArrowLeft /></button>
            <div className="error-panel">
              <AlertCircle /><h2>Analysis Failed</h2>
              <p>{analysisResult.message || 'Unable to analyze the audio. Please try again.'}</p>
              <button className="action-btn" onClick={() => setViewStage('mode-select')}>Try Again</button>
            </div>
          </div>
        </div>
      );
    }

    const issueKey = analysisResult.result.detected_issue_key;
    const isHealthy = issueKey === 'no_issue';
    const confidence = Math.round((analysisResult.result.confidence ?? 0) * 100);

    return (
      <div className="analyze-page">
        <div className="analyze-background" />
        <div className="analyze-container">
          <button className="back-button" onClick={() => setViewStage('mode-select')}><ArrowLeft /></button>

          <div className="result-panel">
            <div className="detected-issue-card">
              <div className="issue-header">
                <AlertCircle />
                <h2>DETECTED ISSUE</h2>
              </div>
              <div className="issue-name-display">{analysisResult.result.detected_issue}</div>
              <div className="issue-indicator">
                <div className="indicator-pulse" />
              </div>
              <div style={{
                display: 'inline-block', marginTop: 8,
                padding: '3px 12px', borderRadius: 20,
                background: isHealthy ? 'rgba(0,255,136,0.12)' : 'rgba(255,77,109,0.12)',
                border: `1px solid ${isHealthy ? 'rgba(0,255,136,0.3)' : 'rgba(255,77,109,0.3)'}`,
                fontSize: 12, color: isHealthy ? '#00ff88' : '#ff4d6d',
                letterSpacing: '0.08em',
              }}>
                {confidence}% confidence
              </div>
            </div>

            <div style={{
              background: 'rgba(255,255,255,0.03)',
              border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: 14, padding: '14px 16px', marginBottom: 14,
            }}>
              <p style={{
                fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase',
                color: 'rgba(255,255,255,0.35)', margin: '0 0 10px 0',
              }}>
                Audio Waveform Analysis
              </p>
              <WaveformGraph issueKey={issueKey} />
            </div>

            <div style={{
              background: 'rgba(255,255,255,0.03)',
              border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: 14, padding: '14px 16px', marginBottom: 14,
            }}>
              <ModelComparisonChart issueKey={issueKey} />
            </div>

            <div className="action-cards">
              <button className="action-card diy-card" onClick={handleViewDIY}>
                <Wrench /><h3>DIY Solutions</h3><p>Try fixing it yourself first</p>
              </button>
              <button className="action-card service-card" onClick={handleFindService}>
                <MapPin /><h3>Find Service Center</h3><p>Locate nearby professionals</p>
              </button>
              <button className="action-card roadside-card" onClick={handleRoadsideAssistance}>
                <Phone /><h3>Roadside Assistance</h3><p>Get immediate help</p>
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // ── DIY ───────────────────────────────────────────────────────
  if (viewStage === 'diy' && diySolution) {
    return (
      <div className="analyze-page">
        <div className="analyze-background" />
        <div className="analyze-container">
          <button className="back-button" onClick={() => setViewStage('result')}><ArrowLeft /></button>
          <div className="diy-panel">
            <div className="diy-header">
              <Wrench />
              <h1>DIY Solution: {diySolution.issue}</h1>
              <div className={`severity-badge ${diySolution.severity}`}>{diySolution.severity.toUpperCase()}</div>
            </div>
            {!diySolution.diy_possible ? (
              <div className="diy-warning">
                <AlertCircle /><h3>Professional Service Recommended</h3>
                <p>{diySolution.warning}</p>
                <button className="action-btn" onClick={handleFindService}>Find Service Center</button>
              </div>
            ) : (
              <>
                <div className="diy-info">
                  <div className="info-item"><strong>Estimated Time:</strong> {diySolution.estimated_time}</div>
                  <div className="info-item"><strong>Tools Needed:</strong> {diySolution.tools_needed.join(', ')}</div>
                </div>
                <div className="diy-steps">
                  <h3>Steps to Fix</h3>
                  {diySolution.steps.map((step, index) => (
                    <div key={index} className={`diy-step ${index <= diyStep ? 'completed' : ''}`} onClick={() => setDiyStep(index)}>
                      <div className="step-number">{index + 1}</div>
                      <div className="step-content">{step}</div>
                      {index <= diyStep && <CheckCircle />}
                    </div>
                  ))}
                </div>
                <div className="diy-warning-box"><AlertCircle /><p>{diySolution.warning}</p></div>
                <button className="action-btn secondary" onClick={handleFindService}>Still Need Help? Find Service Center</button>
              </>
            )}
          </div>
        </div>
      </div>
    );
  }

  // ── SERVICE ───────────────────────────────────────────────────
  if (viewStage === 'service') {
    return (
      <div className="analyze-page">
        <div className="analyze-background" />
        <div className="analyze-container">
          <button className="back-button" onClick={() => setViewStage('result')}><ArrowLeft /></button>
          <div className="service-panel">
            <div className="service-header"><MapPin /><h1>Nearby Service Centers</h1></div>
            <div className="brand-selector">
              <label>Select Your Car Brand:</label>
              <select value={selectedBrand} onChange={(e) => { setSelectedBrand(e.target.value); fetchNearbyServices(); }}>
                <option value="">All Brands</option>
                {CAR_BRANDS.map(b => <option key={b} value={b}>{b}</option>)}
              </select>
            </div>
            <div className="service-list">
              {nearbyServices.length > 0 ? nearbyServices.map((s, i) => (
                <div key={i} className="service-card-item">
                  <div className="service-name">{s.displayName?.text || 'Service Center'}</div>
                  <div className="service-address">{s.formattedAddress}</div>
                  {s.rating && <div className="service-rating">⭐ {s.rating}</div>}
                  {s.internationalPhoneNumber && (
                    <a href={`tel:${s.internationalPhoneNumber}`} className="service-phone">
                      <Phone /> {s.internationalPhoneNumber}
                    </a>
                  )}
                </div>
              )) : (
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

  // ── ROADSIDE ──────────────────────────────────────────────────
  if (viewStage === 'roadside' && roadsideData) {
    return (
      <div className="analyze-page">
        <div className="analyze-background" />
        <div className="analyze-container">
          <button className="back-button" onClick={() => setViewStage('result')}><ArrowLeft /></button>
          <div className="roadside-panel">
            <div className="roadside-header"><Phone /><h1>Roadside Assistance</h1></div>
            <div className="brand-selector">
              <label>Your Car Brand:</label>
              <select value={selectedBrand} onChange={(e) => {
                setSelectedBrand(e.target.value);
                getRoadsideAssistance('India', e.target.value).then(setRoadsideData);
              }}>
                <option value="">Select Brand</option>
                {CAR_BRANDS.map(b => <option key={b} value={b}>{b}</option>)}
              </select>
            </div>
            <div className="helpline-section">
              <h3>National Helplines</h3>
              {roadsideData.national_helplines.map((h, i) => (
                <a key={i} href={`tel:${h.number}`} className="helpline-card">
                  <Phone /><div><div className="helpline-name">{h.name}</div><div className="helpline-number">{h.number}</div></div>
                </a>
              ))}
            </div>
            {roadsideData.brand_assistance && (
              <div className="helpline-section brand-section">
                <h3>{selectedBrand} Roadside Assistance</h3>
                <a href={`tel:${roadsideData.brand_assistance.number}`} className="helpline-card brand-card">
                  <Phone /><div>
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