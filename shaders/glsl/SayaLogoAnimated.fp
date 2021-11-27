// ah shit here we go again

#define overlay(a,b) (a<0.5)?(2.0*a*b):(1.0-(2.0*(1.0-a)*(1.0-b)))
const float pi = 3.14159265358979323846;

vec2 warpcoord( in vec2 uv )
{
	vec2 offset = vec2(0,0);
	offset.x = sin(pi*2.*(uv.x*2.*TEX_AR+timer*.125))*.02;
	offset.y += timer*.25;
	offset.x = cos(pi*2.*(uv.y*2.+timer*.125))*.02;
	return fract(uv+offset);
}

vec2 warpcoord2( in vec2 uv )
{
	vec2 offset = vec2(0,0);
	offset.y = sin(pi*2.*(uv.x*4.*TEX_AR+timer*.25))*.01;
	offset.x = cos(pi*2.*(uv.y*4.+timer*.25))*.01;
	return fract(uv+offset);
}

#ifdef NO_BILINEAR
#define BilinearSampleNoWrap(x,y,z,w) texture(x,y)
#define BilinearSample(x,y,z,w) texture(x,y)
#else
vec4 BilinearSampleNoWrap( in sampler2D tex, in vec2 pos, in vec2 size, in vec2 pxsize )
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

vec4 BilinearSample( in sampler2D tex, in vec2 pos, in vec2 size, in vec2 pxsize )
{
	vec2 disp = floor(pos*vec2(4.,2.))/vec2(4.,2.);
	vec2 f = fract(pos*size);
	pos += (.5-f)*pxsize;
	vec4 p0q0 = texture(tex,fract((pos*vec2(4.,2.)))/vec2(4.,2.)+disp);
	vec4 p1q0 = texture(tex,fract((pos+vec2(pxsize.x,0))*vec2(4.,2.))/vec2(4.,2.)+disp);
	vec4 p0q1 = texture(tex,fract((pos+vec2(0,pxsize.y))*vec2(4.,2.))/vec2(4.,2.)+disp);
	vec4 p1q1 = texture(tex,fract((pos+vec2(pxsize.x,pxsize.y))*vec2(4.,2.))/vec2(4.,2.)+disp);
	vec4 pInterp_q0 = mix(p0q0,p1q0,f.x);
	vec4 pInterp_q1 = mix(p0q1,p1q1,f.x);
	return mix(pInterp_q0,pInterp_q1,f.y);
}
#endif

// based on gimp color to alpha, but simplified
vec4 blacktoalpha( in vec4 src )
{
	vec4 dst = src;
	float dist = 0., alpha = 0.;
	float d, a;
	a = clamp(dst.r,0.,1.);
	if ( a > alpha )
	{
		alpha = a;
		dist = d;
	}
	a = clamp(dst.g,0.,1.);
	if ( a > alpha )
	{
		alpha = a;
		dist = d;
	}
	a = clamp(dst.b,0.,1.);
	if ( a > alpha )
	{
		alpha = a;
		dist = d;
	}
	if ( alpha > 0. )
	{
		float ainv = 1./alpha;
		dst.rgb *= ainv;
	}
	dst.a *= alpha;
	return dst;
}

void SetupMaterial( inout Material mat )
{
	// store these to save some time
	vec2 size = vec2(textureSize(LogoTex,0));
	vec2 pxsize = 1./size;
	// y'all ready for this multilayered madness?
	vec2 uv = vTexCoord.st;
	// copy
	vec4 base = BilinearSampleNoWrap(LogoTex,uv*vec2(.5,.25)+vec2(0.,.25),size,pxsize);
	// overlay
	vec4 tmp = BilinearSample(LogoTex,warpcoord2(uv)*vec2(.5,.25)+vec2(0.,.5),size,pxsize);
	base.r = overlay(base.r,tmp.r);
	base.g = overlay(base.g,tmp.g);
	base.b = overlay(base.b,tmp.b);
	// color to alpha
	base = blacktoalpha(base);
	// separate layer
	tmp = BilinearSampleNoWrap(LogoTex,uv*vec2(.5,.25)+vec2(0.,.75),size,pxsize);
	// overlay
	vec4 tmp2 = BilinearSample(LogoTex,warpcoord(uv)*vec2(.5,.25)+vec2(.5,0.),size,pxsize);
	tmp.r = overlay(tmp.r,tmp2.r);
	tmp.g = overlay(tmp.g,tmp2.g);
	tmp.b = overlay(tmp.b,tmp2.b);
	// mask
	tmp.a = BilinearSampleNoWrap(LogoTex,uv*vec2(.5,.25)+vec2(.5,.25),size,pxsize).x;
	// darken
	tmp2.x = BilinearSampleNoWrap(LogoTex,uv*vec2(.5,.25)+vec2(.5,.5),size,pxsize).x;
	tmp.rgb *= 1.-tmp2.x;
	tmp.a = min(tmp.a+tmp2.x,1.);
	// merge down
	base.rgb = mix(base.rgb,tmp.rgb,tmp.a);
	base.a = min(base.a+tmp.a,1.);
	// add
	base.rgb += BilinearSampleNoWrap(LogoTex,uv*vec2(.5,.25)+vec2(.5,.75),size,pxsize).rgb;
	// clamp borders
	vec2 sz = TEX_SZ;
	vec2 px = uv*sz;
	if ( (px.x <= 1) || (px.x >= (sz.x-1)) || (px.y <= 1) || (px.y >= (sz.y-1)) )
		base = vec4(0.);
	// ding, logo's done
	mat.Base = base;
	mat.Normal = ApplyNormalMap(vTexCoord.st);
}
