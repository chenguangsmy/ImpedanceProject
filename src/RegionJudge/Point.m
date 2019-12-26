%
% Ivana Stevens
% 2018
classdef Point
  
  properties
    x;
    y;
    z;
  end
  
  methods
    function obj = Point(x_new, y_new, z_new)
      obj.x = x_new;
      obj.y = y_new;
      obj.z = z_new;
    end
    
    function out = plus(obj1, obj2)
      out = Point(obj1.x + obj2.x,... 
                  obj1.y + obj2.y,...
                  obj1.z + obj2.z);
    end
    
    function out = minus(obj1, obj2)
      out = Point(obj1.x - obj2.x,... 
                  obj1.y - obj2.y,...
                  obj1.z - obj2.z);
    end
  end
end
