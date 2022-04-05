//Lava Lamp Experimental Shader
//By TanukiVR
//v0.0.0
Shader "Luftprut/Lava Lamp" {
	Properties{
		_Glossiness("Smoothness", Range(0,1)) = 0.9
		_Metallic("Metallic", Range(0,1)) = 0
		_Color("Color", Color) = (0,0,0,1)
		[HDR]_LavaColor("Lava Color", Color) = (1,1,1,1)
		_LavaBottomTopSeparation("Lava Bottom and Top Separation", Range(0, 5)) = 0.3
		_LavaWholeSphereRadius("Lava Encapsulating Sphere Radius", Range(0, 4)) = 0.45
		_LavaWholeSphereRadiusTwo("Lava Stretch", Range(0,2)) = 0.45
		_LavaCentre("Lava Centre Offset", Range(-2,2)) = 0.0
		_LavaBallSize("Lava Ball Size", Range(0, 1)) = 0.175
		_stretchSpawn("Lava Ball Spawn Offset", Range(-3,3)) = 1
		_LavaScrollSpeed("Lave Scroll Speed", Float) = 0.1
		_LavaAttenuation("Internal Fog Density", Float) = 4

		_Ball1("Ball 1", Vector) = (0,1.1,0,1)
		_Ball1_time("Ball 1 Time Offset", Float) = 0

		_Ball2("Ball 2", Vector) = (0.3, 1.3, 0.4, -1)
		_Ball2_time("Ball 2 Time Offset", Float) = 0.5

		_Ball3("Ball 3", Vector) = (0.2, 0.7, -0.4, 1)
		_Ball3_time("Ball 3 Time Offset", Float) = 0.2

		_Ball4("Ball 4", Vector) = (-0.35, 1.7, 0.1, -1)
		_Ball4_time("Ball 4 Time Offset", Float) = 0.8

		_Seed("Object Seed", Range(0.001, 1)) = 1
		[KeywordEnum(None, Polynomial, Exponential)] _SDFSmoothing("SDF Smoothing", Float) = 1

		_Glow("Glow Multiplier", Range(0, 10)) = 1
		_LiquidGlow("Liquid Glow Multiplier", Range(0,10)) = 0
	}
		SubShader{
			Tags { "RenderType" = "Opaque" "DisableBatching" = "True" }
			LOD 200

			CGPROGRAM
			#pragma surface surf Standard fullforwardshadows vertex:vert alpha
			#pragma target 3.0
			#pragma shader_feature _ _SDFSMOOTHING_POLYNOMIAL _SDFSMOOTHING_EXPONENTIAL

		// Higher = quality, lower = performance
		#define RAY_STEPS 16
		// Small constant for gradients calculation
		#define EPSILON 0.001
		// How fast does ray converge on surface (i.e. percentage of distance to move each step)
		#define STRIDE 0.99

		struct Input {
			float3 objViewDir;
			float4 objPos;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
		fixed4 _LavaColor;
		float _LavaBottomTopSeparation;
		float _LavaWholeSphereRadius;
		float _LavaWholeSphereRadiusTwo;
		float _LavaCentre;
		float _LavaScrollSpeed;
		float _LavaBallSize;
		float _LavaAttenuation;

		float4 _Ball1;
		float _Ball1_time;

		float4 _Ball2;
		float _Ball2_time;

		float4 _Ball3;
		float _Ball3_time;

		float4 _Ball4;
		float _Ball4_time;

		float _Seed;
		float _Glow;
		float _LiquidGlow;

		float _stretchSpawn;

#if _SDFSMOOTHING_EXPONENTIAL
		// Exponential smooth min
		#define K 16
		float smin(float a, float b)
		{
			float res = exp2(-K * a) + exp2(-K * b);
			return -log2(res) / K;
		}
#elif _SDFSMOOTHING_POLYNOMIAL
		// Polynomial smooth min (faster)
		#define K 0.2
		float smin(float a, float b)
		{
			float h = saturate(0.5 + 0.5 * (b - a) / K);
			return lerp(b, a, h) - K * h * (1.0 - h);
		}
#else
		// No smoothing (fastest)
		#define smin(a,b) min(a,b)
#endif

		float sdf_lavaLamp(float3 objSpacePos)
		{
			// Metaballs
			float3 ball1pos = float3(_Ball1[0], 4 * _stretchSpawn * frac(_Ball1_time + _Time.y * _LavaScrollSpeed * _Ball1[1] * _Ball1[3] * _Seed) - 2 * _stretchSpawn, _Ball1[2]);
			float3 ball2pos = float3(_Ball2[0],4 * _stretchSpawn * frac(_Ball2_time + _Time.y * _LavaScrollSpeed * _Ball2[1] * _Ball2[3] * _Seed) - 2 * _stretchSpawn, _Ball2[2]);
			float3 ball3pos = float3(_Ball3[0], 4 * _stretchSpawn * frac(_Ball3_time + _Time.y * _LavaScrollSpeed * _Ball3[1] * _Ball3[3] * _Seed) - 2 * _stretchSpawn, _Ball3[2]);
			float3 ball4pos = float3(_Ball4[0],4 * _stretchSpawn * frac(_Ball4_time + _Time.y * _LavaScrollSpeed * _Ball4[1] * _Ball4[3] * _Seed) - 2 * _stretchSpawn, _Ball4[2]);

			float sdf_balls = length(objSpacePos - ball1pos);
			sdf_balls = smin(sdf_balls, length(objSpacePos - ball2pos));
			sdf_balls = smin(sdf_balls, length(objSpacePos - ball3pos));

			float distance = sdf_balls - (_LavaBallSize);
			// Top and bottom
			distance = smin(distance, min(_LavaBottomTopSeparation - objSpacePos.y, objSpacePos.y + _LavaBottomTopSeparation));
			float3 sep = distance;
			// Encapsulating sphere
			distance = max(distance, length(objSpacePos) - _LavaWholeSphereRadius - EPSILON);

			//To enable Lava Stretch factor
			float3 p = objSpacePos;
			p.y += _LavaCentre;

			p.y -= clamp(p.y, 0.0, _LavaWholeSphereRadiusTwo);

			float3 cyl = length(p) - _LavaWholeSphereRadius;
			cyl = max(cyl, min(_LavaBottomTopSeparation - objSpacePos.y, objSpacePos.y + _LavaBottomTopSeparation));
			distance = min(cyl, distance);
			return distance;
		}

		float3 gradient_lavaLamp(float3 objSpacePos)
		{
			float3 dx = float3(EPSILON, 0, 0);
			float3 dy = float3(0, EPSILON, 0);
			float3 dz = float3(0, 0, EPSILON);

			float dist0 = sdf_lavaLamp(objSpacePos);

			return float3(
				sdf_lavaLamp(objSpacePos + dx) - dist0,
				sdf_lavaLamp(objSpacePos + dy) - dist0,
				sdf_lavaLamp(objSpacePos + dz) - dist0);
		}

		float3 raycastToLavaSurface(float3 objSpaceRayStart, float3 objSpaceRayDirection)
		{
			float3 rayPos = objSpaceRayStart;
			for (int i = 0; i < RAY_STEPS; i++)
			{
				float distance = sdf_lavaLamp(rayPos);
				rayPos += distance * objSpaceRayDirection * STRIDE;
			}
			return rayPos;
		}

		void vert(inout appdata_full v, out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.objPos = v.vertex;
			o.objViewDir = ObjSpaceViewDir(v.vertex);
		}

		void surf(Input IN, inout SurfaceOutputStandard o)
		{
			// Standard surface properties
			o.Albedo = _Color.rgb;
			o.Alpha = _Color.a;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			//a
			// Lava lamp effect sampling
			float3 viewDirNormalized = -normalize(IN.objViewDir);
			float3 lavaSurfacePos = raycastToLavaSurface(IN.objPos, viewDirNormalized);
			float3 lavaSurfaceNormal = normalize(gradient_lavaLamp(lavaSurfacePos));

			// Lava lamp effect shading
			float attenuation = exp(_LavaAttenuation * length(lavaSurfacePos - IN.objPos));
			float lavaShaded = saturate(dot(-viewDirNormalized, lavaSurfaceNormal) * 0.5 + 0.5);
			o.Emission = saturate(_LavaColor * (lavaShaded / attenuation) * _Glow);
			o.Emission += saturate(_Color * _LiquidGlow);
		}
		ENDCG
	}
		FallBack "Standard"
}
