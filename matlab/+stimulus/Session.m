%{ 
session : int
-----
session_datetime = CURRENT_TIMESTAMP : datetime
%}

classdef Session < dj.Manual
end