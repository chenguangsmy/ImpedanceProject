% log graph

function Y = Radius2DifficultyLogX(B,X)

b0 = B(1);
b1 = B(2);
b2 = B(3);
% b3 = B(4);

Y = 1./(b1*log(-X+b0) + b2);

end

