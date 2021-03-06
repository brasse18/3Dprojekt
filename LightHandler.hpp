/*
* TODO: Should probably move MAX_LIGHTS to this file and rename it
* The cLightBuffer might have to be public
*/


#ifndef LIGHTHANDLER_HPP
#define LIGHTHANDLER_HPP

#include "GlobalResources.hpp"

const int NR_OF_LIGHTS = 2;

class LightHandler
{
public:
	LightHandler(DirectX::XMFLOAT4 CAM_POS);
	~LightHandler();

	bool InitializeLights(ID3D11Device* Dev, DirectX::XMFLOAT4 CAM_POS);
	bool BindLightBuffer(ID3D11DeviceContext* DevCon, DirectX::XMFLOAT4 CAM_POS);
	bool CreateLightBuffer(ID3D11Device* Dev);
	bool CreateShadowMap(ID3D11Device* Dev);

	//shadow mapping
	ID3D11Texture2D* mShadowMap;
	ID3D11DepthStencilView* mShadowMapDepthView;
	ID3D11ShaderResourceView* mShadowMapSRView;
private:
	struct Light
	{
		Light(DirectX::XMFLOAT4 pos = DirectX::XMFLOAT4(0.0f, 0.0f, 0.0f, 1.0f),
			DirectX::XMFLOAT3 col = DirectX::XMFLOAT3(1.0f, 1.0f, 1.0f),
			int hasS = 0,
			float c_att = 1.0f,
			float l_att = 0.0f,
			float q_att = 0.0f,
			float amb = 0.0f)
			: PositionWS(pos),
			Color(col),
			hasShadow(hasS),
			constantAttenuation(c_att),
			linearAttenuation(l_att),
			quadraticAttenuation(q_att),
			ambientCoefficient(amb)
		{}

		DirectX::XMFLOAT4 PositionWS;
		DirectX::XMFLOAT3 Color;
		int hasShadow;
		float constantAttenuation;
		float linearAttenuation;
		float quadraticAttenuation;
		float ambientCoefficient;
	};

	struct cLightBuffer
	{
		cLightBuffer() 
		{
			//DirectX::XMStoreFloat4(&cameraPositionWS, CAM_POS);
			globalAmbient = DirectX::XMFLOAT4(0.05f, 0.05f, 0.05f, 0.05f);

			for (int i = 0; i < NR_OF_LIGHTS; i++)
			{
				LightArray[i] = Light();
			}
		}

		DirectX::XMFLOAT4 cameraPositionWS;
		DirectX::XMFLOAT4 globalAmbient;
		Light LightArray[NR_OF_LIGHTS];
	};
	static_assert((sizeof(cLightBuffer) % 16) == 0, "Constant Light Buffer size must be 16-byte aligned");

	cLightBuffer mLightBufferData;
	ID3D11Buffer* mLightBuffer;

};


#endif // !LIGHTHANDLER_HPP
