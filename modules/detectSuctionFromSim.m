function [tf, info] = detectSuctionFromSim(Plv_log, varargin)
% detectSuctionFromSim  Heuristic: simulation entered a suction-like regime.
%
% Uses minimum left-ventricular pressure in a steady-state tail of Plv_log.
% Spin-up transients are reduced by restricting to the last SteadyStateFrac
% of the record (by time, not sample count).
%
% Name-Value pairs:
%   PlvMinThreshold  (default 0)   — if min Plv in window is below this (mmHg), flag
%   SteadyStateFrac  (default 0.5) — fraction of [t0,tend] to keep (from the end)
%
% Outputs:
%   tf   — logical, true if excluded as suction-like
%   info — struct with plv_min_ss, threshold, reason (char)

p = inputParser;
addParameter(p, 'PlvMinThreshold', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'SteadyStateFrac', 0.5, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
parse(p, varargin{:});

thr = p.Results.PlvMinThreshold;
frac = p.Results.SteadyStateFrac;

info = struct('plv_min_ss', NaN, 'threshold', thr, 'reason', '');

if isempty(Plv_log) || size(Plv_log, 2) < 2
    tf = false;
    return;
end

tcol = Plv_log(:, 1);
pv = Plv_log(:, 2);
t0 = tcol(1);
t1 = tcol(end);
if ~(isfinite(t0) && isfinite(t1)) || t1 <= t0
    tf = false;
    return;
end

t_cut = t1 - frac * (t1 - t0);
idx = tcol >= t_cut;
if ~any(idx)
    idx = true(size(tcol));
end

plv_min_ss = min(pv(idx));
info.plv_min_ss = plv_min_ss;

tf = plv_min_ss < thr;
if tf
    info.reason = sprintf('Plv_min_steady=%.2f mmHg < %.2f mmHg (suction heuristic)', plv_min_ss, thr);
end

end
