function [projections]=project(vS,fS,vT,fT)

TRS = triangulation(fS,vS); 
normalsS=vertexNormal(TRS);


[IDXsource,Dsource]=knnsearch(vT,vS);
vector_s_to_t=vT(IDXsource,:)-vS;

% Project vector_s_to_t onto the normal direction at each vertex
% Since vertexNormal returns unit normals, we don't need to divide by norm squared
projections = vS + sum(vector_s_to_t .* normalsS, 2) .* normalsS;
