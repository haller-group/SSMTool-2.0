function y = lang(x, p)
%LANG   'coll'-compatible encoding of langford vector field.

x1  = x(1,:);
x2  = x(2,:);
x3  = x(3,:);
om  = p(1,:);
ro  = p(2,:);
eps = p(3,:);

y(1,:) = (x3-0.7).*x1-om.*x2;
y(2,:) = om.*x1+(x3-0.7).*x2;
y(3,:) = 0.6+x3-x3.^3/3-(x1.^2+x2.^2).*(1+ro.*x3)+eps.*x3.*x1.^3;

end
