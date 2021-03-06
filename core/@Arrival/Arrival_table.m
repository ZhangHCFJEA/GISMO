%Arrival the blueprint for Arrival objects in GISMO
% An Arrival object is a container for phase arrival metadata
% See also Catalog
classdef Arrival
    properties(Dependent)
    %properties
        channelinfo
        time
        %arid
        %jdate
        iphase
        %deltim
        %azimuth
        %delaz
        %slow
        %delslo
        %ema
        %rect
        amp
        per
        %clip
        %fm
        signal2noise
        %qual
        %auth
    end
    properties
        waveforms
    end
    properties(Hidden)
        table
    end
    methods
        function obj = Arrival(sta, chan, time, iphase, varargin)
            % Parse required, optional and param-value pair arguments,
            % set default values, and add validation conditions          
            p = inputParser;
            p.addRequired('sta', @iscell);
            p.addRequired('chan', @iscell);
            %p.addRequired('time', @(t) t>0 & t<now+1);
            p.addRequired('time', @isnumeric);
            p.addRequired('iphase', @iscell);
            p.addParameter('amp', NaN, @isnumeric);
            p.addParameter('per', NaN, @isnumeric);
            p.addParameter('signal2noise', NaN, @isnumeric);
            
            % Missed several properties out here just because of laziness.
            % Add them as needed.
            p.parse(sta, chan, time, iphase, varargin{:});
            fields = fieldnames(p.Results);
            for i=1:length(fields)
                field=fields{i};
                val = p.Results.(field);
                eval(sprintf('%s = val;',field));
            end
            ctag = ChannelTag.array('',sta,'',chan)';
            obj.table = table(time, datestr(time,26), datestr(time,'HH:MM'), datestr(time,'SS.FFF'), ctag.string(), iphase, amp, per, signal2noise, ...
                'VariableNames', {'time' 'date' 'hour_minute' 'second' 'channelinfo' 'iphase' 'amp' 'per' 'signal2noise'})
            obj.table = sortrows(obj.table, 'time', 'ascend'); 
            fprintf('\nGot %d arrivals\n',height(obj.table));edit 
            misc_fields = struct;
                
        end
        
        function val = get.time(obj)
            val = obj.table.time;
        end 
        
        function val = get.channelinfo(obj)
            val = obj.table.channelinfo;
        end        
        
        function val = get.iphase(obj)
            val = obj.table.iphase;
        end
 
        function val = get.amp(obj)
            val = obj.table.amp;
        end            
        
        function val = get.signal2noise(obj)
            val = obj.table.signal2noise;
        end
        
        function obj = set.amp(obj, amp)
            obj.table.amp = amp;
        end       
        
        function summary(obj, showall)
        % ARRIVAL.SUMMARY Summarise Arrival object
            for c=1:numel(obj)
                obj(c)
                numarrs = height(obj(c).table)
                fprintf('Number of arrivals: %d\n',numarrs);
                if numarrs > 0
                    if ~exist('showall','var')
                            showall = false;
                    end
                    if numel(obj) == 1
                        if height(obj.table) <= 50 || showall
                            disp(obj.table)
                        else
                            disp(obj.table([1:50],:))

                            disp('* Only showing first 50 rows/arrivals - to see all rows/arrivals use:')
                            disp('*      arrivalObject.disp(true)')
                        end
                    end
                end
            end
        end
        
        function self2 = subset(self, columnname, findval)
            self2 = self;
            N = numel(self.time);
            indexes = [];
            if ~exist('findval','var')
                % assume columnname is actually row numbers
                indexes = columnname;
            else

                for c=1:N
                    gotval = eval(sprintf('self.%s(c);',columnname));
                    if isa(gotval,'cell')
                        gotval = cell2mat(gotval);
                    end
                    if isnumeric(gotval)
                        if gotval==findval
                            indexes = [indexes c];
                        end
                    else
                        if strcmp(gotval,findval)
                            indexes = [indexes c];
                        end
                    end
                end
            end
            self2.table = self.table(indexes,:);
            
%             % now go into misc_fields and apply same index subset to
%             % anything with N elements
%             fields = fieldnames(self.misc_fields);
%             for fieldnum=1:numel(fields)
%                 fieldval = getfield(self.misc_fields, fields{fieldnum});
%                 if numel(fieldval)==N
%                     self2.misc_fields = setfield(self2.misc_fields, fields{fieldnum}, fieldval(indexes));
%                 end
%             end

            self2.waveforms = self.waveforms(indexes);
            
        end 
        
        % prototypes
        catalogobj = associate(self, maxTimeDiff)
        %arrivalobj = setminman(self, w, pretrig, posttrig, maxtimediff)
        arrivalobj = addmetrics(self, maxtimediff)
        arrivalobj = addwaveforms(self, datasourceobj, pretrigsecs, posttrigsecs);
    end
    methods(Static)
        function self = retrieve(dataformat, varargin)
        %ARRIVAL.RETRIEVE Read arrivals from common file formats & data sources.
        % retrieve can read phase arrivals from different earthquake catalog file 
        % formats (e.g. Seisan, Antelope) and data sources (e.g. IRIS DMC) into a 
        % GISMO Catalog object.
        %
        % Usage:
        %       arrivalObject = ARRIVAL.RETRIEVE(dataformat, 'param1', _value1_, ...
        %                                                   'paramN', _valueN_)
        % 
        % dataformat may be:
        %
        %   * 'iris' (for IRIS DMC, using irisFetch.m), 
        %   * 'antelope' (for a CSS3.0 Antelope/Datascope database)
        %   * 'seisan' (for a Seisan database with a REA/YYYY/MM/ directory structure)
        %   * 'zmap' (converts a Zmap data strcture to a Catalog object)
        %
        % See also CATALOG, IRISFETCH, CATALOG_COOKBOOK

        % Author: Glenn Thompson (glennthompson1971@gmail.com)

        %% To do:
        % Implement name-value parameter pairs for all methods
        % Test the Antelope method still works after factoring out db_load_origins
        % Test the Seisan method more
        % Add in support for 'get_arrivals'
            
            debug.printfunctionstack('>')
            self = [];
            switch lower(dataformat)
                case {'css3.0','antelope', 'datascope'}
                    if admin.antelope_exists()
                        try
                            self = Arrival.read_arrivals.antelope(varargin{:});
                        catch
                            % no arrivals
                        end
                    else
                        warning('Antelope toolbox for MATLAB not found')
                    end
                case 'hypoellipse'
                    self = read_hypoellipse(varargin{:});
                otherwise
                    self = NaN;
                    fprintf('format %s unknown\n\n',dataformat);
            end

            debug.printfunctionstack('<')
        end
        
        %cookbook()
    end
end