

img = rgb2gray(imread('LaTeX Equations\eq8.jpg'));

detected = zeros(size(-5:0.5:15));
i = 1;
err = detected;
for theta = -5:0.5:15
rotated = imrotate(img,theta,'bilinear');
Mrot = ~imrotate(true(size(img)),theta,'bilinear');
rotated(Mrot&~imclearborder(Mrot)) = 255;
thresh = graythresh(rotated);
bw_skew = im2bw(rotated, thresh);

detected(i) = fn_deskew2(bw_skew);
if theta ==0
    err(i) = abs((detected(i)-theta));
else
    err(i) = abs((detected(i)-theta)/theta);
end
i = i+1;
end

