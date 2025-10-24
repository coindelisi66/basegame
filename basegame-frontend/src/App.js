import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import './App.css';

const BASEGAME_ADDRESS = "YOUR_BASEGAME_ADDRESS"; // Deploy sonrası güncelle
const PASS_ADDRESS = "YOUR_BASEGAME_PASS_ADDRESS"; // Deploy sonrası güncelle
const BASEGAME_ABI = []; // Remix’ten BaseGame ABI’sini kopyala
const PASS_ABI = []; // Remix’ten BaseGamePass ABI’sini kopyala

function App() {
  const [account, setAccount] = useState(null);
  const [hasPass, setHasPass] = useState(false);
  const [sessionStatus, setSessionStatus] = useState("Not started");
  const [sessionsToday, setSessionsToday] = useState(0);

  const connectWallet = async () => {
    if (window.ethereum) {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const accounts = await provider.send("eth_requestAccounts", []);
      setAccount(accounts[0]);

      const passContract = new ethers.Contract(PASS_ADDRESS, PASS_ABI, provider);
      const balance = await passContract.balanceOf(accounts[0]);
      setHasPass(balance > 0);

      const baseGameContract = new ethers.Contract(BASEGAME_ADDRESS, BASEGAME_ABI, provider);
      const sessions = await baseGameContract.sessionsPlayedToday(accounts[0]);
      setSessionsToday(sessions.toNumber());
    } else {
      alert("Metamask yükleyin!");
    }
  };

  const joinSession = async () => {
    if (!hasPass) {
      alert("BaseGame Pass NFT’si gerekli!");
      return;
    }
    if (sessionsToday >= 3) {
      alert("Günlük 3 seans limitine ulaştınız!");
      return;
    }
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const contract = new ethers.Contract(BASEGAME_ADDRESS, BASEGAME_ABI, signer);
    try {
      const tx = await contract.joinSession({ value: ethers.parseEther("0.01") });
      await tx.wait();
      setSessionStatus("Seansa katıldın! BaseGame Pass NFT’n yolda!");
      setSessionsToday(sessionsToday + 1);
    } catch (error) {
      console.error(error);
      alert("Hata: " + error.message);
    }
  };

  const shareOnFarcaster = () => {
    const farcasterUrl = `https://warpcast.com/~/compose?text=I%20joined%20BaseGame%20-%2015%20Dakikada%20Zengin%20Olma%20Oyunu%20and%20got%20a%20cool%20NFT%20jeton!%20Join%20on%20Base!`;
    window.open(farcasterUrl, '_blank');
  };

  return (
    <div className="App">
      <h1>BaseGame: 15 Dakikada Zengin Olma Oyunu</h1>
      {!account ? (
        <button onClick={connectWallet}>Cüzdanı Bağla</button>
      ) : (
        <>
          <p>Hesap: {account}</p>
          <p>NFT Durumu: {hasPass ? "BaseGame Pass NFT’n var!" : "Pass NFT gerekli!"}</p>
          <p>Günlük Seans: {sessionsToday}/3</p>
          <button onClick={joinSession} disabled={!hasPass || sessionsToday >= 3}>
            Seansa Katıl (0.01 ETH)
          </button>
          <p>Durum: {sessionStatus}</p>
          <button onClick={shareOnFarcaster}>Farcaster’da Paylaş</button>
        </>
      )}
    </div>
  );
}

export default App;
