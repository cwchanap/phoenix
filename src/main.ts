import { mount } from 'svelte';
import App from './App.svelte';
import './app.css';

if (import.meta.env.DEV && import.meta.hot) {
  window.__PHOENIX_HMR_COUNT__ = 0;
  const recordUpdate = () => {
    window.__PHOENIX_HMR_COUNT__ = (window.__PHOENIX_HMR_COUNT__ ?? 0) + 1;
  };
  import.meta.hot.on('vite:afterUpdate', recordUpdate);
  import.meta.hot.dispose(() => {
    import.meta.hot?.off('vite:afterUpdate', recordUpdate);
    delete window.__PHOENIX_HMR_COUNT__;
  });
}

mount(App, { target: document.getElementById('app')! });
