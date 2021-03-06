function opts = state_BP_add(opts)
% add a new chart to point list

% construct new chart from special point
ev     = opts.efunc.ev;
events = opts.cont.events;

chart = opts.cseg.curr_chart;
% bug: remove commented code
% if ~isfield(chart, 'p')
%   [opts chart]         = opts.cseg.tangent_space(opts, chart);
%   [opts chart]         = opts.cseg.tangent(opts, chart);
%   [opts chart chart.p] = opts.efunc.monitor_F(opts, chart, chart.x, chart.t);
%   [opts chart.e]       = opts.efunc.events_F (opts, chart.p);
% end
if isfield(events, 'hanidx')
  chart.pt_type = events.point_type;
else
  chart.pt_type = ev.point_type{events.evidx(1)};
end
chart.ep_flag = 1;

[opts opts.cseg] = opts.cseg.add_BP(opts, chart);
[opts opts.cseg] = opts.cseg.evlist_init(opts, opts.cseg.evlist);

if isempty(opts.cseg.evlist)
  opts.cont.state     = 'MX_check';
else
  opts.cseg.src_chart = opts.cseg.ptlist{end};
  opts.cont.state     = 'ev_locate';
end
end
