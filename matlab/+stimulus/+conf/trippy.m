function trippy

control = stimulus.getControl;
control.clearAll   % clear trial queue and cached conditions.

cond.rng_seed = 1:4;
cond.duration = 16;   % (s) trial duration
cond.tex_ydim = 90;  %
cond.tex_xdim = 160;  %
cond.screen_height = 85;  % degrees
cond.frame_downsample = 1; % 
cond.xnodes = 8;     % x dimension of low-res phase movie
cond.ynodes = 6;      % y dimension of low-res phase movie
cond.up_factor = 24;  % upscale factor from low-res to texture dimensions
cond.temp_freq = 2.5;   % (Hz) temporal frequency if the phase pattern were static
cond.temp_kernel_length = 61;  % length of Hanning kernel used for temporal filter. Controls the rate of change of the phase pattern.
cond.spatial_freq = 0.06;  % (cy/degree) approximate max. Actual frequency spectrum ranges propoprtionally.

params = stimulus.utils.factorize(cond);
fprintf('Total duration: %4.2f s\n', sum([params.duration]))

% generate conditions
hashes = control.makeConditions(stimulus.Trippy, params);

% push trials
control.pushTrials(hashes(randperm(numel(hashes))))
end
