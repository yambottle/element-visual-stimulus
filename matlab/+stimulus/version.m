function varargout = version
    % report Element Visual Stimulus version
    
    v = struct('major', 0, 'minor', 1, 'patch', 0);
    
    if nargout
        varargout{1}=v;
    else
        fprintf('\nElement Visual Stimulus version %d.%d.%d\n\n', v.major, v.minor, v.patch)
    end