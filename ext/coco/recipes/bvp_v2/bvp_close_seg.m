function prob = bvp_close_seg(prob, tbid, data)
%BVP_CLOSE_SEG   Append an instance of 'bvp' to problem.
%
% Add boundary conditions to an instance of 'coll'.
%
% Differs from bvp_v1 by providing support for optional boundary conditions
% function data, including a slot function that responds to the 'update'
% signal and modifies the function data after each successfully located
% solution point.
%
% PROB = BVP_CLOSE_SEG(PROB, TBID, DATA)
%
% PROB - Continuation problem structure.
% TBID - Toolbox instance identifier.
% DATA - Toolbox data structure.

% Copyright (C) Frank Schilder, Harry Dankowicz
% $Id: bvp_close_seg.m 2839 2015-03-05 17:09:01Z fschild $

if ~isempty(data.bc_update) % Optional inclusion of boundary conditions function data
  data.tbid = tbid;
  data = coco_func_data(data); % Convert to func_data class for shared access
  prob = coco_add_slot(prob, tbid, @bvp_bc_update, data, 'update');
end
segtbid  = coco_get_id(tbid, 'seg.coll'); % Create 'coll' toolbox instance identifier
[fdata uidx] = coco_get_func_data(prob, segtbid, 'data', 'uidx'); % Extract 'coll' data structure and context-dependent index array
uidx = uidx([fdata.T_idx; fdata.x0_idx; fdata.x1_idx; fdata.p_idx]); % Subset to T, x0, x1, and p
if isempty(data.dfdxhan) % Optional inclusion of explicit Jacobian of boundary conditions
  prob = coco_add_func(prob, tbid, @bvp_F, data, 'zero', 'uidx', uidx);
else
  prob = coco_add_func(prob, tbid, @bvp_F, @bvp_DFDU, data, 'zero', ...
    'uidx', uidx);
end
prob = coco_add_slot(prob, tbid, @coco_save_data, data, 'save_full');

end

function [data y] = bvp_F(prob, data, u)
%BVP_F   COCO-compatible wrapper to boundary conditions.
%
% Expects encoding of boundary conditions as function of T, x0, x1, and p.
%
% Differs from bvp_v1 by including function data in call to fhan.

T  = u(data.T_idx);  % Extract interval length
x0 = u(data.x0_idx); % Extract trajectory end point at t=0
x1 = u(data.x1_idx); % Extract trajectory end point at t=1
p  = u(data.p_idx);  % Extract problem parameters

y  = data.fhan(data.bc_data, T, x0, x1, p);

end

function [data J] = bvp_DFDU(prob, data, u)
%BVP_DFDU   COCO-compatible wrapper to linearization of boundary conditions.
%
% Expects encoding of boundary conditions as function of T, x0, x1, and p.
%
% Differs from bvp_v1 by including function data in call to dfdxhan.

T  = u(data.T_idx);  % Extract interval length
x0 = u(data.x0_idx); % Extract trajectory end point at t=0
x1 = u(data.x1_idx); % Extract trajectory end point at t=1
p  = u(data.p_idx);  % Extract problem parameters

J  = data.dfdxhan(data.bc_data, T, x0, x1, p);

end

function data = bvp_bc_update(prob, data, cseg, varargin)
%BVP_BC_UPDATE   COCO-compatible wrapper to boundary condition function data update function.
%
% Use information about current solution to update function data
% parameterizing the execution of the boundary condition zero function.

uidx = coco_get_func_data(prob, data.tbid, 'uidx'); % Context-dependent index set
u    = cseg.src_chart.x(uidx); % Current chart
T    = u(data.T_idx);  % Extract interval length
x0   = u(data.x0_idx); % Extract trajectory end point at t=0
x1   = u(data.x1_idx); % Extract trajectory end point at t=1
p    = u(data.p_idx);  % Extract problem parameters
data.bc_data = data.bc_update(data.bc_data, T, x0, x1, p);

end
