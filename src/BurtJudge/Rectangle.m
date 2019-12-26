%
% Ivana Stevens
% 2018
classdef Rectangle
  
  properties
    tl;
    bl;
    br;
    tr;
  end
  
  methods
    function obj = Rectangle(tl, bl, br, tr)
      % todo: ensure points are in fact points
      obj.tl = tl;
      obj.br = br;
      obj.tr = tr;
      obj.bl = bl;
    end
  end
end
