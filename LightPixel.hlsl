/**
* Course: DV142 - 3D-Programming
* Authors: Viktor Enfeldt, Peter Meunier
*
* File: LightPixel.hlsl
*
* File summary: Pixel shader used in the light pass
*	Calculates Phong lighting and shadows using 16-tap percentage closer filtering.
*/

// TODO? Gamma correction

#define NR_OF_LIGHTS 2

// For syntax highlighting
#if defined(__INTELLISENSE__)
#define SHADOW_MAP_SIZE 1.0f
#endif


#ifdef SHADOW_MAP_SIZE
static const float inverseShadowMapSize = rcp(SHADOW_MAP_SIZE);
#else
static const float inverseShadowMapSize = 0.0;
#endif


// Textures from G-Buffers
Texture2D<float4> NormalTexture			: register(t0); // x-y-z-unused
Texture2D<float4> PositionTexture		: register(t1); // x-y-z-unused
Texture2D<float4> DiffuseAlbedoTexture	: register(t2); // r-g-b-unused
Texture2D<float4> SpecularTexture		: register(t3); // r-g-b-specularPower
Texture2D<float>  ShadowMap				: register(t4); // depth

SamplerComparisonState compSampler		: register(s0);

cbuffer shadowMapMatrix			: register(b0)
{
	float4x4 lightViewProjection;
	float4 cameraPosition;
}

struct Light
{
	float4 light_positionWS;
	float3 color;
	int hasShadow; // 1 = true
	float constant_attenuation;
	float linear_attenuation;
	float quadratic_attenuation;
	float ambient_coefficient;
};

cbuffer pointLightProperties	: register (b1)
{
	float4 global_ambient;
	Light Lights[NR_OF_LIGHTS];
};

struct PS_IN
{
	float4 PositionCS	: SV_Position; //pixel location
};

// Turns a texel offset into a texCoord offset since the comparison sampler uses texture coordinates
float2 TexOffset(int u, int v)
{
	return float2(u, v) * inverseShadowMapSize;
}

// 16-tap (4x4 texel area) Percentage-Closer Filtering using a comparison sampler
float ShadowCoefficient(float2 texCoord, float lightDepth)
{
	float shadow_sum;

	for (float y = -1.5; y <= 1.5; y += 1.0)
	{
		for (float x = -1.5; x <= 1.5; x += 1.0)
		{
			shadow_sum += ShadowMap.SampleCmpLevelZero(compSampler, texCoord + TexOffset(x, y), lightDepth);
		}
	}
	return shadow_sum *= 0.0625; // Division by 16;
}


// diffuse coefficient = cos(light-normal-angle) = dot(toLight, normal), if toLight has been normalized
float DiffuseCoefficient(float3 toLight, float3 normal)
{
	return max(0.0, dot(toLight, normal));
}

float3 DiffuseComponent(float diffuseCoefficient, float3 diffuseColor, int i)
{
	return diffuseCoefficient * (diffuseColor * Lights[i].color);
}

// specular coefficient = cos(lightReflection-camera-angle)^s = dot(lightReflection, surfaceToCamera)^s, s = specular power
float3 SpecularComponent(float3 toLight, float3 toCamera, float3 normal, float4 specularColor, int i)
{
	float specular_coefficient = pow(saturate(dot(reflect(-toLight, normal), toCamera)), specularColor.a);
	return specular_coefficient * (specularColor.rgb * Lights[i].color);
}

// Attenuation = 1 / (c + ld + q(d^2))
// c = constant, l = linear, q = quadratic attenuation, d = distance
float Attenuation(float3 positionWS, int i)
{
	float light_dist = distance(Lights[i].light_positionWS.xyz, positionWS);
	return rcp(Lights[i].constant_attenuation + light_dist * (Lights[i].linear_attenuation + light_dist * Lights[i].quadratic_attenuation));
}

float4 PS_main ( PS_IN input ) : SV_Target
{
	// Values from the G-Buffers
	float3 normal			= NormalTexture.Load(int3(input.PositionCS.xy, 0)).rgb;
	float3 positionWS		= PositionTexture.Load(int3(input.PositionCS.xy, 0)).rgb;
	float3 diffuseColor		= DiffuseAlbedoTexture.Load(int3(input.PositionCS.xy, 0)).rgb;
	float4 specularValues	= SpecularTexture.Load(int3(input.PositionCS.xy, 0));

	// Phong lighting variables
	float diffuse_coefficient;
	float3 diffuse_component, specular_component;


	// Used for the diffuse and specular calculations
	float3 to_camera = normalize(cameraPosition.xyz - positionWS); // vector from surface to camera
	float3 to_light; // vector from surface to the light source

	// Used for the shadow map calculations
	float4 light_view_pos = mul(float4(positionWS, 1.0), lightViewProjection); // The clip space position of the point from the light's point of view
	float bias = 0.000015;
	
	float2 shadow_tex_coord;
	shadow_tex_coord.x = (light_view_pos.x * rcp(light_view_pos.w) * 0.5) + 0.5;  // Dividing by w gives positions as normalized device coordinates [-1, 1]
	shadow_tex_coord.y = (-light_view_pos.y * rcp(light_view_pos.w) * 0.5) + 0.5;  // Dividing by 2.0 and adding 0.5 gives position as uv coordinates [0, 1]

	// calculate the distance from the light to the texel (the z value in NDC)
	float light_depth_value = light_view_pos.z * rcp(light_view_pos.w) - bias;

	// Test if the point is outside the light's view frustum
	bool outside_shadow_map = (saturate(shadow_tex_coord.y) != shadow_tex_coord.y && saturate(shadow_tex_coord.x) != shadow_tex_coord.x) ? true : false;
	
	float shadow_coefficient = (outside_shadow_map) ? 1.0 : ShadowCoefficient(shadow_tex_coord, light_depth_value);

	// FOR DEBUGGING: Overwrites the Percentage-Closer Filtering
	//shadow_coefficient = (!outside_shadow_map) ? ShadowMap.SampleCmpLevelZero(compSampler, shadow_tex_coord - TexOffset(0.5, 0.5), light_depth_value) : 1.0;
	//shadow_coefficient = (light_depth_value < ShadowMap.Load(int3(shadow_tex_coord/inverseShadowMapSize, 0)).r) ? 1.0 : 0.0;
	// !FOR DEBUGGING

	float3 final_color = global_ambient.rgb * diffuseColor.rgb; // All positions are hit by the global ambient light
	
	for (int i = 0; i < NR_OF_LIGHTS; i++)
	{
		// The light contributes with its ambient part even if the pixel is in shadow
		final_color += Lights[i].ambient_coefficient * (Lights[i].color * diffuseColor); // light intesities

		// If the pixel is in full shadow then the diffuse and specular parts won't contribute to the final color so we won't calculate them
		if (Lights[i].hasShadow != 1 || shadow_coefficient != 0.0)
		{
			to_light = normalize(Lights[i].light_positionWS.xyz - positionWS);

			diffuse_coefficient = DiffuseCoefficient(to_light, normal);
			diffuse_component = DiffuseComponent(diffuse_coefficient, diffuseColor, i);

			specular_component = (diffuse_coefficient != 0.0) ? SpecularComponent(to_light, to_camera, normal, specularValues, i) : float3(0.0, 0.0, 0.0);

			final_color += (diffuse_component + specular_component) * (Attenuation(positionWS, i) * ((Lights[i].hasShadow == 1) ? shadow_coefficient : 1.0));
			

			//final_color += diffuse_component * (Attenuation(positionWS, i));
			//final_color += specular_component * (Attenuation(positionWS, i));
			//final_color += Lights[i].color * (Attenuation(positionWS, i));
		}
	}

	//final_color = normal;
	//final_color = positionWS / 50.0;
	//final_color = diffuseColor;
	//final_color = specularValues.rgb;
	//final_color = float3(shadow_tex_coord, 0.0);
	//final_color = float3(shadow_coefficient, shadow_coefficient, shadow_coefficient);

	return float4(saturate(final_color), 1.0);
}
