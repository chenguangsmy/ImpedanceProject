%
%  Manage the logic of determining where imaginary target region is
%  and determining if the cursor is still within acceptable range
%
% Ivana Stevens
% 2018
classdef TargetZone
  
  properties
    % Private variables
    zone_;
    target_;
    targetLim_;
    center_; % System Center
    zDepth_;
    angle_; % Radians
    width_;
    
    % Public variables
    zoneR;
    targetR;
    targetLim;
    errorLim;
    angle;
  end
  
  methods
    % Constructor
    function obj = TargetZone(centerX, centerY, centerZ, width, length, ...
        errLim, depth)
      obj.center_ = Point(centerX, centerY, centerZ);
      dx = length/2;
      dy = width/2;
      
      tl = obj.center_ + Point(dx, dy, 0);
      bl = obj.center_ + Point(dx, -dy, 0);
      br = obj.center_ + Point(-dx, -dy, 0);
      tr = obj.center_ + Point(-dx, dy, 0);
      
      % set base zone and target region
      obj.zone_ = Rectangle(tl, bl, br, tr);
      obj.target_ = Rectangle(tl, bl, br, tr);
      
      %set accessible zone and target region
      obj.zoneR = Rectangle(tl, bl, br, tr);
      obj.targetR = Rectangle(tl, bl, br, tr);
      
      % set acceptable depth. Probably not used...
      obj.zDepth_ = depth;
      obj.width_ = width;
      
      % set Limit you can be outside of target
      obj.errorLim = errLim;
    end
    
    % Distance from system center, and the width of target region
    function setTarget(obj, distance, targetWidth)
      % delta for center
      dx = distance;
      targetCenter = obj.center_ + Point(-dx, 0, 0); % Negative dx b/c reasons.
      
      % delta for width
      dx = targetWidth/2;
      dy = obj.width_/2;
      tl = targetCenter + Point( dx, dy, 0);
      bl = targetCenter + Point( dx,-dy, 0);
      br = targetCenter + Point(-dx,-dy, 0);
      tr = targetCenter + Point(-dx, dy, 0);
      
      % set target region
      obj.target_ = Rectangle(tl, bl, br, tr);
      obj.targetR = obj.rotateRectangle(obj.target_, obj.angle_);
      
      % set Target error boundary for center
      dx = (targetWidth/2) + obj.errorLim;
      
      tl = targetCenter + Point( dx, dy, 0);
      bl = targetCenter + Point( dx,-dy, 0);
      br = targetCenter + Point(-dx,-dy, 0);
      tr = targetCenter + Point(-dx, dy, 0);
      
      % set target region with error boundary
      obj.targetLim_ = Rectangle(tl, bl, br, tr);
      obj.targetLimR = obj.rotateRectangle(obj.targetLim_, obj.angle_);
    end


    % Rotate public rectangle and target, theta is in radians
    function rotate(obj, theta)
      % set angle
      obj.angle_ = theta;
      % Rotate zone
      obj.zoneR = obj.rotateRectangle(obj.zone_, theta);
      % Rotate target
      obj.targetR = obj.rotateRectangle(obj.target_, theta);
    end


    % Determine if a point is within a rectangle (should be private)
    function out = inRegion(obj, rectangle, p)
      V = [rectangle.tl, rectangle.bl, rectangle.br, rectangle.tr];
      out = obj.cn_PnPoly(p, V, 4) == 1; % 4 points in rectangle
    end


    % See if point is within the target with error boundary
    function out = inZone(obj, x,  y,  z)
      p = Point(x, y, z);
      out = obj.inRegion(obj.zoneR, p);
    end


    % See if point is within the target with error boundary
    function out = inTargetLim(obj, x,  y,  z)
      
      p = Point(x, y, z);
      out = TargetZone.inRegion(obj, obj.targetLimR, p);
    end
    

    % See if point is within the target
    function out = inTarget(obj, x, y, z)
      p = Point(x, y, z);
      out = TargetZone.inRegion(obj.targetR, p);
    end


    %  insure vector in the correct direction
    function out = inDirection( x1,  x2,  y1,  y2,  tolerance)
      dot = x1*x2 + y1*y2;
      det = x1*y2 - y1*x2;
      ang = atan2(det, dot); % TODO, is this radians or degrees?
      out = abs(ang) < tolerance;
    end
    

    %  Return magnitude of vector in 2d
    function out = magnitude( dx,  dy)
      out = sqrt(dx*dx + dy*dy);
    end
    
    function out = adequateForce(obj, fx,  fy,  minMag,  tolerance)
      % rotate unit vector about 0,0
      dir = TargetZone.inDirection(fx, cos(obj.angle), fy,...
        cos(obj.angle), tolerance);
      mag = TargetZone.magnitude(fx,fy) >= minMag;
      out =  dir && mag;
    end
    
    %%% Private functions -------------------------------------------------
    
    % a Point is defined by its coordinates {int x, y;}
    %  isLeft(): tests if a point is Left|On|Right of an infinite line.
    %  Input:  three points P0, P1, and P2
    %  Return: >0 for P2 left of the line through P0 and P1
    %          =0 for P2  on the line
    %          <0 for P2  right of the line
    %  See: Algorithm 1 "Area of Triangles and Polygons"
    %
    function out =  isLeft( P0,  P1,  P2)
      out = ( (P1.x - P0.x)*(P2.y - P0.y) - (P2.x -  P0.x)*(P1.y - P0.y) );
    end
    
    
    % cn_PnPoly(): crossing number test for a point in a polygon
    % Input:   P = a point,
    %          V[] = vertex points of a polygon V[n+1] with V[n]=V[0]
    % Return:  0 = outside, 1 = inside
    % This code is patterned after [Franklin, 2000]
    function out = cn_PnPoly(obj, P,  V,  n)
      
      cn = 0; % the  crossing number counter
      
      % loop through all edges of the polygon
      for i = 1:n   % edge from V[i]  to V[i+1]
         % an upward crossing
        if (((V(i).y <= P.y) && ( V(mod((i+1),n) + 1).y > P.y)) ...
            || (( V(i).y > P.y ) && ( V(mod((i+1), n) + 1).y <=  P.y))) % a downward crossing
         
          % compute  the actual edge-ray intersect x-coordinate
          vt = (P.y  - V(i).y) / (V(mod((i+1),n) + 1).y - V(i).y);
          % P.x < intersect
          if (P.x <  V(i).x + vt * (V(mod((i+1),n) + 1).x - V(i).x)) 
            cn = cn + 1;   % a valid crossing of y=P.y right of P.x
          end
        end
      end
      out = (cn&1); % 0 if even (out), and 1 if  odd (in)
    end
    

    % Rotate rectangle about system center in the XY plane theta in radians
    function out =  rotateRectangle(obj, rect,  theta)      
      tl = obj.rotatePoint(rect.tl, theta);
      bl = obj.rotatePoint(rect.bl, theta);
      br = obj.rotatePoint(rect.br, theta);
      tr = obj.rotatePoint(rect.tr, theta);
      
      out =  Rectangle(tl, bl, br, tr);
    end    
    

    % Rotate point about system center in the XY plane, theta is in radians
    function out = rotatePoint(obj, p,  theta)      
      ox = obj.center_.x;
      oy = obj.center_.y;
      
      qx = ox + (cos(theta) * (p.x - ox)) - (sin(theta) * (p.y - oy));
      qy = oy + (sin(theta) * (p.x - ox)) + (cos(theta) * (p.y - oy));
      
      out =  Point(qx, qy, p.z);
    end
    
  end
  
end


