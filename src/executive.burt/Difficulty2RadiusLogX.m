% log graph

function Y = Difficulty2RadiusLogX(B,X)

b0 = B(1);
b1 = B(2);
b2 = B(3);
% b3 = B(4);

Y = b0 - exp(((1./X) - b2)/b1);

end

