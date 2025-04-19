#ifdef RAY_MARCH
#else
#define RAY_MARCH


            #include "RayMarchVariables.cginc"
            
            #define MAX_DIST 100.0f
            #define SURF_DIST 0.01f
            #define MAX_STEPS 100
            #define PI 3.14
            
            float sdBox( float3 p, float3 s, float3 b )
            {
              float3 q = abs(p - s) - b;
              return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
            }

            float sdSphere(float3 p , float4 s){

                return length(p - s.xyz) - s.w;
            }

            //https://www.shadertoy.com/view/lt3BW2
            float smin( float a, float b, float k )
            {
                k *= 1.0;
                float r = exp2(-a/k) + exp2(-b/k);
                return -k*log2(r);
            }

            float opUnion( float d1, float d2 )
            {
                return min(d1,d2);
            }

            float opSubtraction( float d1, float d2 )
            {
                return max(-d1,d2);
            }

            float opIntersection( float d1, float d2 )
            {
                return max(d1,d2);
            }

            float opSmoothUnion( float d1, float d2, float k )
            {
                float h = max(k-abs(d1-d2),0.0);
                return min(d1, d2) - h*h*0.25/k;
            }

            float opSmoothSubtraction( float d1, float d2, float k )
            {
                return -opSmoothUnion(d1,-d2,k);
    
                //float h = max(k-abs(-d1-d2),0.0);
                //return max(-d1, d2) + h*h*0.25/k;
            }

            float opSmoothIntersection( float d1, float d2, float k )
            {
                return -opSmoothUnion(-d1,-d2,k);

                //float h = max(k-abs(d1-d2),0.0);
                //return max(d1, d2) + h*h*0.25/k;
            }


            float GetDist(float3 p);

            float GetDist0(float3 p) {
	            float4 s1 = float4(1,1,1,1);

                float sd1 = sdSphere(p, s1);

                return sd1;
            }



            float RayMarch(float3 ro, float3 rd) {
	            float d=0.;
    

                for(int i=0; i<MAX_STEPS; i++) {
    	            float3 p = ro + rd * d;
                    float dS = (GetDist(p));

                    d += dS;
                    
                    if(d>MAX_DIST)
                        break;
                    
                    if(dS<=SURF_DIST) 
                        break;


                }
    
                return d;
            }
            
            float3 GetNormal(float3 p){

                float3 eps = float3(0.001, 0, 0 );

                float3 normal = float3(
                    GetDist(p + eps.xyy) - GetDist(p - eps.xyy),
                    GetDist(p + eps.yxy) - GetDist(p - eps.yxy),
                    GetDist(p + eps.yyx) - GetDist(p - eps.yyx)
                );

                return normalize(normal);
            }

#endif
