// Root App component for StartupFromScratch UI
import React from 'react';
import { Routes, Route, Link } from 'react-router-dom';
import { Helmet } from 'react-helmet-async';

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
        <Route path="/" element={<><h2>Home Page</h2></>} />
        <Route path="about" element={<><h2>About Page</h2></>} />
      </Routes>
    </>
  );
} 