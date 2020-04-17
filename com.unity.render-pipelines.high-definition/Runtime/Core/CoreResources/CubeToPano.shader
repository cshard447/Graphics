Shader "Hidden/CubeToPano" {
Properties {
    _SrcBlend ("", Float) = 1
    _DstBlend ("", Float) = 1
}

HLSLINCLUDE
#pragma editor_sync_compilation
#pragma target 4.5
#pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

#include "UnityCG.cginc"

UNITY_DECLARE_TEXCUBE(_SrcCubeTexture);
UNITY_DECLARE_TEXCUBEARRAY(_SrcCubeTextureArray);

uniform int     _CubeMipLvl;
uniform int     _CubeArrayIndex;
uniform bool    _BuildPDF;
uniform int     _PreMultiplyByCosTheta;
uniform int     _PreMultiplyBySolidAngle;
uniform int     _PreMultiplyByJacobian; // Premultiply by the Det of Jacobian, to be "Integration Ready"
float4          _Sizes; // float4( outSize.xy, 1/outSize.xy )

struct v2f
{
    float4 vertex : SV_POSITION;
    float2 texcoord : TEXCOORD0;
};

v2f vert (float4 vertex : POSITION, float2 texcoord : TEXCOORD0)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(vertex);
    o.texcoord = texcoord.xy;
    return o;
}

float2 DirectionToSphericalTexCoordinate(float3 dir_in) // use this for the lookup
{
    float3 dir = normalize(dir_in);
    // coordinate frame is (-Z,X) meaning negative Z is primary axis and X is secondary axis.
    float recipPi = 1.0/3.1415926535897932384626433832795;
    return float2( 1.0-0.5*recipPi*atan2(dir.x, -dir.z), asin(dir.y)*recipPi + 0.5 );
}

float3 SphericalTexCoordinateToDirection(float2 sphTexCoord)
{
    float pi = 3.1415926535897932384626433832795;
    float theta = (1-sphTexCoord.x) * (pi*2);
    float phi = (sphTexCoord.y-0.5) * pi;

    float csTh, siTh, csPh, siPh;
    sincos(theta, siTh, csTh);
    sincos(phi, siPh, csPh);

    // theta is 0 at negative Z (backwards). Coordinate frame is (-Z,X) meaning negative Z is primary axis and X is secondary axis.
    return float3(siTh*csPh, siPh, -csTh*csPh);
}

float3 GetDir(float2 texCoord)
{
    return SphericalTexCoordinateToDirection(texCoord.xy);
}

float SampleToPDFMeasure(float3 value)
{
    return (value.r + value.g + value.b)*(1.0f/3.0f);
}

float SampleToPDFMeasure(float4 value)
{
    return SampleToPDFMeasure(value.rgb);
}

float GetScale(float angle)
{
    float scale = 1.0f;
    float pi = 3.1415926535897932384626433832795f;

    if (_PreMultiplyByJacobian == 1)
    {
        scale *= sin(angle); // Spherical Jacobian
    }
    if (_PreMultiplyByCosTheta == 1)
    {
        scale *= max(-cos(angle), 0.0f);
    }
    if (_PreMultiplyBySolidAngle == 1)
    {
        scale *= _Sizes.z*_Sizes.w;
        scale *= pi*pi*0.5f;
    }

    return scale;
}

float4 frag(v2f i) : SV_Target
{
    uint2  pixCoord = (uint2)i.vertex.xy;
    float3 dir     = GetDir(i.texcoord.xy);

    float3 output;
    if (_BuildPDF == 1)
        output = SampleToPDFMeasure(UNITY_SAMPLE_TEXCUBE_LOD(_SrcCubeTexture, dir, (float)_CubeMipLvl).rgb).xxx;
    else
        output = UNITY_SAMPLE_TEXCUBE_LOD(_SrcCubeTexture, dir, (float) _CubeMipLvl).rgb;

    float scale = 1.0f;
    float pi    = 3.1415926535897932384626433832795f;
    float angle = i.texcoord.y*pi;

    output *= GetScale(angle);

    return float4(output.rgb, max(output.r, max(output.g, output.b)));
}

float4 fragArray(v2f i) : SV_Target
{
    uint2  pixCoord = (uint2)i.vertex.xy;
    float3 dir      = GetDir(i.texcoord.xy);

    float3 output;
    if (_BuildPDF == 1)
        output = SampleToPDFMeasure(UNITY_SAMPLE_TEXCUBEARRAY_LOD(_SrcCubeTextureArray, float4(dir, _CubeArrayIndex), (float)_CubeMipLvl).rgb).xxx;
    else
        output = UNITY_SAMPLE_TEXCUBEARRAY_LOD(_SrcCubeTextureArray, float4(dir, _CubeArrayIndex), (float)_CubeMipLvl).rgb;

    float scale = 1.0f;
    float pi    = 3.1415926535897932384626433832795f;
    float angle = (1.0f - i.texcoord.y)*pi;

    output *= GetScale(angle);

    return float4(output.rgb, max(output.r, max(output.g, output.b)));
}

ENDHLSL

SubShader {
    Pass
    {
        ZWrite Off
        ZTest Always
        Cull Off
        Blend Off

        HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
        ENDHLSL
    }

    Pass
    {
        ZWrite Off
        ZTest Always
        Cull Off
        Blend Off

        HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment fragArray
        ENDHLSL
    }
}
Fallback Off
}
