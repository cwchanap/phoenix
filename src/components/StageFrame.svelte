<script lang="ts">
  import { onMount } from 'svelte';
  import type { Snippet } from 'svelte';
  import { fitStage } from '../ui/stageScale';

  let { children }: { children: Snippet } = $props();
  let fit = $state(fitStage(640, 360));

  onMount(() => {
    const resize = () => {
      fit = fitStage(window.innerWidth, window.innerHeight);
    };

    resize();
    window.addEventListener('resize', resize);
    return () => window.removeEventListener('resize', resize);
  });
</script>

<div
  class="stage-frame"
  data-stage-frame
  style:left={`${fit.left}px`}
  style:top={`${fit.top}px`}
  style:width={`${fit.width}px`}
  style:height={`${fit.height}px`}
  data-stage-scale={fit.scale}
>
  <div class="logical-stage" data-logical-stage style:transform={`scale(${fit.scale})`}>
    {@render children()}
  </div>
</div>
