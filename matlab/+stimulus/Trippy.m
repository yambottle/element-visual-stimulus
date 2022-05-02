%{
# Trippy Visual Stimulus
-> stimulus.Condition
---
rng_seed                    : double                        # random number generate seed
packed_phase_movie          : longblob                      # phase movie before spatial and temporal interpolation
tex_ydim                    : smallint                      # (pixels) texture dimension
tex_xdim                    : smallint                      # (pixels) texture dimension
duration                    : float                         # (s) trial duration
frame_downsample            : tinyint                       # 1=60 fps, 2=30 fps, 3=20 fps, 4=15 fps, etc
xnodes                      : tinyint                       # x dimension of low-res phase movie
ynodes                      : tinyint                       # y dimension of low-res phase movie
up_factor                   : tinyint                       # spatial upscale factor
screen_height               : float                         # presumed screen height (degrees)
temp_freq                   : float                         # (Hz) temporal frequency if the phase pattern were static
temp_kernel_length          : smallint                      # length of Hanning kernel used for temporal filter. Controls the rate of change of the phase pattern.
spatial_freq                : float                         # (cy/degree) approximate max. The actual frequencies may be higher.
%}



classdef Trippy < stimulus.core.Visual & dj.Manual

    properties(Constant)
        version = 'a1'
    end

    methods(Static)

        function cond = make(cond)
            if ~isfield(cond, 'packed_phase_movie')
                cond.packed_phase_movie = ...
                    stimulus.Trippy.make_packed_phase_movie(cond);
            end
        end


        function cond = prepare(cond)
            % get called after before display
            if ~isfield(cond, 'movie')
                phase = stimulus.Trippy.interp_time(cond.packed_phase_movie, cond);
                phase = stimulus.Trippy.interp_space(phase, cond);
                cond.movie = uint8((cos(2*pi*phase)+1)/2*253+1);
            end
        end
    
    end

    methods
        function showTrial(self, cond)
            % execute a single trial with a single cond
            fps = self.screen.fps;  % must be 60 
            assert(fps==60, 'Frame rate must be 60')
            self.screen.frameStep = cond.frame_downsample;
            for frame=1:size(cond.movie, 3)
                % if self.screen.escape, break, end
                tex = Screen('MakeTexture', self.win, cond.movie(:, :, frame));
                Screen('DrawTexture', self.win, tex, [], self.rect)
                self.flip(struct('checkDroppedFrames', frame>1))
                Screen('close', tex)  % delete the texture
            end
        end
    end


    methods(Static)

        function phase = make_packed_phase_movie(cond)
            % Make compressed phase movie.
            r = RandStream.create('mt19937ar','Seed', cond.rng_seed);
            nframes = ceil(cond.duration * 60 / cond.frame_downsample);
            n = [cond.ynodes cond.xnodes];
            k = cond.temp_kernel_length;
            assert(k>=3 && mod(k,2)==1)
            k2 = ceil(k/4);
            compensator = 8.0;
            scale = compensator*cond.up_factor*cond.spatial_freq*cond.screen_height/cond.tex_ydim;
            phase = scale*r.rand(ceil((nframes+k-1)/k2), prod(n));
        end


        function phase = interp_time(phase, cond)
            fps = 60 / cond.frame_downsample;
            nframes = ceil(cond.duration * fps);
            % lowpass in time
            k = cond.temp_kernel_length;
            assert(k>=3 && mod(k,2)==1)
            k2 = ceil(k/4);
            phase = upsample(phase, k2);
            tempKernel = hanning(k);
            tempKernel = k2/sum(tempKernel)*tempKernel;
            phase=conv2(phase,tempKernel,'valid');  % lowpass in time
            phase = phase(1:nframes,:);

            % add motion
            phase=bsxfun(@plus, phase, (1:nframes)'/fps*cond.temp_freq);
        end


        function movie = interp_space(phase, cond)
            % upscale to full size
            n = [cond.ynodes cond.xnodes];
            f = cond.up_factor;
            movie = zeros(cond.ynodes*f, cond.xnodes*f, size(phase,1));
            for i=1:size(phase,1)
                movie(:,:,i) = stimulus.Trippy.frozen_upscale(reshape(phase(i,:),n),f);
            end
            % crop to screen size
            movie = movie(1:cond.tex_ydim, 1:cond.tex_xdim, :);
        end


        function img = frozen_upscale(img, factor)
            % Performs fast resizing of the image by the given integer factor with
            % gaussian interpolation.
            % Never modify this function. Ever. It was used to generate Version 1 trippy movies.
            % Frozen on 2015-12-30. No changes are allowed ever.

            for i=1:2
                img = upsample(img', factor, round(factor/2));
                L = size(img,1);
                k = gausswin(L,sqrt(0.5)*L/factor);
                k = ifftshift(factor/sum(k)*k);
                img = real(ifft(bsxfun(@times, fft(img), fft(k))));
            end
        end


        function test()

            cond.rng_seed = 1;
            cond.tex_ydim = 90;  %
            cond.tex_xdim = 160;  %
            cond.screen_height = 85;  % degrees
            cond.duration = 30;   % (s) trial duration
            cond.frame_downsample = 1; % 
            cond.xnodes = 8;     % x dimension of low-res phase movie
            cond.ynodes = 6;      % y dimension of low-res phase movie
            cond.up_factor = 24;  % upscale factor from low-res to texture dimensions
            cond.temp_freq = 2.5;   % (Hz) temporal frequency if the phase pattern were static
            cond.temp_kernel_length = 61;  % length of Hanning kernel used for temporal filter. Controls the rate of change of the phase pattern.
            cond.spatial_freq = 0.06;  % (cy/degree) approximate max. Actual frequency spectrum ranges propoprtionally.

            cond = stimulus.Trippy.make(cond);
            cond = stimulus.Trippy.prepare(cond);
            phase = cond.packed_phase_movie;
            movie = cond.movie;

            % plot statistics
            fps = 60;
            degPerPixel = cond.screen_height/cond.tex_ydim;
            [gx, gy] = gradient(phase, degPerPixel);
            spatial_freq = sqrt(gx.^2 + gy.^2);
            temp_freq = (phase(:,:,[2:end end]) - phase(:,:,[1 1:end-1]))*fps/2;
            subplot 121,  histogram(spatial_freq(:),300); box off, xlabel 'log spatial frequencies (cy/degree)'
            xlim([0 0.2]), grid on
            set(gca, 'YTickLabel', [])
            subplot 122,  histogram(abs(temp_freq(:)),300);   box off,  xlabel 'temporal frequencies (Hz)'
            xlim([0 15]), grid on
            set(gca, 'YTickLabel', [])
            set(gcf, 'PaperSize', [8 3], 'PaperPosition', [0 0 8 3])

            % save movie
            fname = '~/Desktop/trippy';
            fprintf('writing %s', fname)
            v = VideoWriter(fname, 'MPEG-4');
            v.FrameRate = fps;
            v.Quality = 100;
            open(v)
            writeVideo(v, permute(movie, [1 2 4 3]));
            close(v)
            disp done
        end
    end
end
