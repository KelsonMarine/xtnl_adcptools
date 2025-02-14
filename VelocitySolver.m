classdef VelocitySolver < ADCPDataSolver
    % Abstract base class to solve ADCP repeat transect velocity data
    %
    %   Subclasses should implement the get_solver_input method.
    %
    %   obj=VelocitySolver(...) allows to set properties upon construction.
    %   Depending on the class objects are assigned to a specific property:
    %   VMADCP -> obj.adcp (required)
    %   Mesh -> obj.mesh (required)
    %   Bathymetry -> obj.bathymetry
    %   XSection -> obj.xs
    %   Filter -> obj.ensemble_filter
    %   VelocityModel -> obj.velocity_model
    %
    %  VelocitySolver properties:
    %   adcp - VMADCP object with the adcp data
    %   mesh - Mesh object defining a mesh
    %   bathy - Defines the bathymetry
    %   xs - Defines the cross-section
    %   ensemble_filter - defines repeat transects to be processed
    %   velocity_model - defines the velocity model to fit
    %
    %   VelocitySolver methods:
    %   get_parameters - get velocity model parameters on mesh
    %   get_velocity - get velocity on mesh
    %   rotate_to_xs - rotates velocity to cross-section direction
    %
    %   see also: VMADCP, Mesh, Bathymetry, XSection, Filter,
    %   TimeBasedVelocitySolver, LocationBasedVelocitySolver
    properties
        % VelocityModel/rotation
        %
        %   Horizontal rotation applied to velocity. Value must be a
        %   scalar, finite and real double.
        %
        % see also: VelocityModel
        rotation(1,1) double {mustBeFinite, mustBeReal} = 0;
    end
    properties(Dependent, SetAccess=private)
        % ncomponents x ncomponents rotation matrix
        rotation_matrix (:,:) double {mustBeFiniate, mustBeReal}
    end
    methods
        function rotation_matrix = get.rotation_matrix(obj)
            rotation_matrix = [cos(obj.rotation), -sin(obj.rotation), 0;...
                sin(obj.rotation), cos(obj.rotation), 0;...
                0, 0, 1];
        end
        function varargout = get_velocity(obj, varargin)
            %   Get velocity from model parameters
            %
            %   vel=get_velocity(obj) computes the velocity in the mesh cells by using
            %   the velocity computed by combining the beam velocities measured at the
            %   same time (this is done by the ADCP class). Velocities that where
            %   measured within a mesh cell (this is determined by the Mesh class) are
            %   averaged.
            %
            %   [vel,cov_vel] = get_velocity(obj) also returns the standard
            %   deviation in the velocity
            if ~isscalar(obj)
                varargout = cell(1,nargout);
                [varargout{:}] = obj.run_method('get_velocity',varargin{:});
                return
            end

            varargout = cell(1,nargout);
            [varargout{:}] = obj.get_data(varargin{:});
            R = shiftdim(obj.rotation_matrix',-1);
            varargout{1} = helpers.matmult(R, varargout{1});

            if nargout > 1
                RT = shiftdim(obj.rotation_matrix,-1);
                varargout{2} = helpers.matmult(RT,varargout{2});
                varargout{2} = helpers.matmult(varargout{2}, R);
            end
        end

        function [vel, cov]=rotate_to_xs(obj, orig_vel, orig_cov)
            % Rotates velocity to direction of cross-section
            %
            %   vel=obj.rotate_to_xs(orig_vel) Rotates the velocity orig_vel
            %   to the direction of the cross-section.
            %
            %   [vel, cov]=obj.rotate_to_xs(orig_vel, orig_cov) also rotates
            %   the covariance matrix
            %
            % See also: VelocitySolver, get_velocity
            xs = [obj.xs];
            u = cellfun(@(x) x(:,1),orig_vel,'UniformOutput',false);
            v = cellfun(@(x) x(:,2),orig_vel,'UniformOutput',false);
            [vels, veln] = xs.xy2sn_vel( ...
                u, ...
                v);
            vel = cellfun(@(a,b,c) [a,b,c(:,3)], vels, veln, orig_vel, ...
                'UniformOutput',false);
            if nargin > 2
                Trot = cellfun(@(x) x(:,1:2,1:2), orig_cov, ...
                    'UniformOutput',false);
                Tsn = xs.xy2sn_tens(Trot);
                cov = cellfun(@(a,b) cat(3, [a, b(:,3,1:2)],...
                    b(:,:,3)),Tsn,orig_cov, ...
                    'UniformOutput',false);
            end
        end

    end

end