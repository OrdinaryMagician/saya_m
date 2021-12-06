// ah shit here we go again

#define overlay(a,b) (a<0.5)?(2.0*a*b):(1.0-(2.0*(1.0-a)*(1.0-b)))
const float pi = 3.14159265358979323846;

vec2 warpcoord( in vec2 uv )
{
	vec2 offset = vec2(0,0);
	offset.x = sin(pi*2.*(uv.x*4.+timer*.125))*.02;
	offset.y += timer*.25;
	offset.x = cos(pi*2.*(uv.y*2.+timer*.125))*.02;
	return fract(uv+offset);
}

vec2 warpcoord2( in vec2 uv )
{
	vec2 offset = vec2(0,0);
	offset.y = sin(pi*2.*(uv.x*8.+timer*.25))*.01;
	offset.x = cos(pi*2.*(uv.y*4.+timer*.25))*.01;
	return fract(uv+offset);
}

// based on gimp color to alpha, but simplified
vec4 blacktoalpha( in vec4 src )
{
	vec4 dst = src;
	float alpha = 0.;
	float a;
	a = clamp(dst.r,0.,1.);
	if ( a > alpha ) alpha = a;
	a = clamp(dst.g,0.,1.);
	if ( a > alpha ) alpha = a;
	a = clamp(dst.b,0.,1.);
	if ( a > alpha ) alpha = a;
	if ( alpha > 0. )
	{
		float ainv = 1./alpha;
		dst.rgb *= ainv;
	}
	dst.a *= alpha;
	return dst;
}
#ifdef NO_BILINEAR
#define BilinearSample(x,y,z,w) texture(x,y)
#else
vec4 BilinearSample( in sampler2D tex, in vec2 pos, in vec2 size, in vec2 pxsize )
{
	vec2 f = fract(pos*size);
	pos += (.5-f)*pxsize;
	vec4 p0q0 = texture(tex,pos);
	vec4 p1q0 = texture(tex,pos+vec2(pxsize.x,0));
	vec4 p0q1 = texture(tex,pos+vec2(0,pxsize.y));
	vec4 p1q1 = texture(tex,pos+vec2(pxsize.x,pxsize.y));
	vec4 pInterp_q0 = mix(p0q0,p1q0,f.x);
	vec4 pInterp_q1 = mix(p0q1,p1q1,f.x);
	return mix(pInterp_q0,pInterp_q1,f.y);
}
#endif

void SetupMaterial( inout Material mat )
{
	// store these to save some time
	vec2 size = vec2(textureSize(Layer1,0));
	vec2 pxsize = 1./size;
	// y'all ready for this multilayered madness?
	vec2 uv = vTexCoord.st;
	// layer 1 base
	vec4 base = BilinearSample(Layer1,uv,size,pxsize);
	// overlay layer 2 red
	vec4 tmp;
	tmp.x = BilinearSample(Layer2,warpcoord2(uv),size,pxsize).r;
	base.r = overlay(base.r,tmp.x);
	base.g = overlay(base.g,tmp.x);
	base.b = overlay(base.b,tmp.x);
	// add layer 5
	base.rgb += BilinearSample(Layer5,uv,size,pxsize).rgb;
	// black to alpha
	base.a = max(base.r,max(base.g,base.b));
	// separate layer 3
	tmp = BilinearSample(Layer3,uv,size,pxsize);
	// overlay layer 4
	vec4 tmp2 = BilinearSample(Layer4,warpcoord(uv),size,pxsize);
	tmp.r = overlay(tmp.r,tmp2.r);
	tmp.g = overlay(tmp.g,tmp2.g);
	tmp.b = overlay(tmp.b,tmp2.b);
	// mask layer 2 green
	tmp.a = BilinearSample(Layer2,uv,size,pxsize).g;
	// darken layer 2 blue
	tmp2.x = BilinearSample(Layer2,uv,size,pxsize).b;
	tmp.rgb *= 1.-tmp2.x;
	tmp.a = min(tmp.a+tmp2.x,1.);
	// merge down
	base.rgb = mix(base.rgb,tmp.rgb,tmp.a);
	base.a = min(base.a+tmp.a,1.);
	// clamp
	base = clamp(base,0.,1.);
	// ding, logo's done
	mat.Base = base;
}
