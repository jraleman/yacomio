import React, { useState, useEffect } from 'react';

const LOCAL_STORAGE_KEY = 'yacomio-save';

function loadGame() {
  const data = localStorage.getItem(LOCAL_STORAGE_KEY);
  if (data) return JSON.parse(data);
  return {
    ep: 0,
    epPerSecond: 1,
    upgrades: [],
  };
}

function saveGame(state) {
  localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(state));
}

const upgradesList = [
  {
    id: 'rna',
    name: 'Unlock RNA',
    cost: 10,
    effect: state => ({ ...state, epPerSecond: state.epPerSecond + 1 }),
    description: 'Unlocks RNA, doubling EP generation.',
  },
  {
    id: 'dna',
    name: 'Unlock DNA Replication',
    cost: 50,
    effect: state => ({ ...state, epPerSecond: state.epPerSecond + 3 }),
    description: 'Unlocks DNA replication, greatly increasing EP gain.',
  },
  // Add more upgrades as needed
];

export default function App() {
  const [state, setState] = useState(loadGame());

  // Passive EP generation
  useEffect(() => {
    const interval = setInterval(() => {
      setState(prev => {
        const newState = { ...prev, ep: prev.ep + prev.epPerSecond };
        saveGame(newState);
        return newState;
      });
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  // Tap to boost EP
  const tapMicrobe = () => {
    setState(prev => {
      const newState = { ...prev, ep: prev.ep + 5 };
      saveGame(newState);
      return newState;
    });
  };

  // Buy upgrade
  const buyUpgrade = upgrade => {
    if (state.ep >= upgrade.cost && !state.upgrades.includes(upgrade.id)) {
      const newState = upgrade.effect({
        ...state,
        ep: state.ep - upgrade.cost,
        upgrades: [...state.upgrades, upgrade.id],
      });
      setState(newState);
      saveGame(newState);
    }
  };

  return (
    <div style={{ fontFamily: 'sans-serif', padding: 24, maxWidth: 500, margin: '0 auto' }}>
      <h1>YaComio!</h1>
      <h2>Microbial Beginnings</h2>
      <p><strong>Evolution Points (EP):</strong> {state.ep}</p>
      <p><strong>EP per second:</strong> {state.epPerSecond}</p>
      <button onClick={tapMicrobe} style={{ fontSize: 18, margin: '12px 0' }}>Tap Microbe (+5 EP)</button>
      <h3>Upgrades</h3>
      <ul>
        {upgradesList.map(upg => (
          <li key={upg.id} style={{ marginBottom: 8 }}>
            <button
              onClick={() => buyUpgrade(upg)}
              disabled={state.ep < upg.cost || state.upgrades.includes(upg.id)}
            >
              {upg.name} ({upg.cost} EP)
            </button>
            <span style={{ marginLeft: 8 }}>{upg.description}</span>
          </li>
        ))}
      </ul>
      <p style={{ marginTop: 32, color: '#888' }}>
        Progress is saved automatically. More features coming soon!
      </p>
    </div>
  );
}
