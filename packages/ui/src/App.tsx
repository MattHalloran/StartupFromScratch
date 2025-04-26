// Root App component for StartupFromScratch UI
import React, { useState } from 'react';
import { Routes, Route, Link } from 'react-router-dom';
import { Helmet } from 'react-helmet-async';

// --- File Reading Component (Integrated) ---
function FileOpener() {
  const [fileContent, setFileContent] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleOpenFileClick = async () => {
    try {
      // Access the function exposed by the preload script
      // Note: Typing for window.electronAPI might be needed for stricter TS checks
      const content = await (window as any).electronAPI.openFile();
      if (content !== null) {
        setFileContent(content);
        setError(null);
      } else {
        // User cancelled the dialog
        setFileContent(null);
        setError(null);
      }
    } catch (err: any) {
      console.error("Error opening or reading file:", err);
      setError(`Error: ${err.message || 'Could not read file'}`);
      setFileContent(null);
    }
  };

  return (
    <div>
      <button onClick={handleOpenFileClick}>Open Text File</button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
      {fileContent !== null && (
        <div>
          <h3>File Content:</h3>
          <pre style={{ border: '1px solid #ccc', padding: '10px', background: '#f9f9f9' }}>{fileContent}</pre>
        </div>
      )}
    </div>
  );
}

// --- Main App Component ---

interface AppProps {
  sso?: { clientId: string; issuer: string };
}

export default function App({ sso }: AppProps) {
  // Use passed-in SSO config or fallback to dummy
  const ssoconfig = sso ?? { clientId: 'dummy-client-id', issuer: 'http://dummy-issuer' };

  return (
    <>
      <Helmet>
        <meta name="sso-client-id" content={ssoconfig.clientId} />
        <meta name="sso-issuer"    content={ssoconfig.issuer}    />
      </Helmet>
      <nav>
        <Link to="/">Home</Link> | <Link to="/about">About</Link>
      </nav>
      <Routes>
        <Route 
          path="/" 
          element={
            <>
              <h2>Home Page</h2>
              <FileOpener />
            </>
          } 
        />
        <Route path="about" element={<><h2>About Page</h2></>} />
      </Routes>
    </>
  );
} 