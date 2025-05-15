using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Serialization;
using Object = UnityEngine.Object;
using Random = UnityEngine.Random;

public class Cloud : MonoBehaviour
{
    public NoiseGenerator generator;
    public WeatherSystem weatherSystem;
    public Camera mainCamera;

    private RenderTexture _shapeRt3d;
    private RenderTexture _detailRt3d;
    private RenderTexture _weatherTex;


    private Material _CloudMat;
    private Material _BlendCloud;
    private RenderTexture cloudRT;
    public Texture2D curlNoise;
    public Texture2D blueNoise;
    [Space(20)]


    public int maxStep;
    public float globalCoverage;
    [Range(0, 1000)] public float detailScale;
    [Range(0, 1000)] public float noiseScale;
    [Range(0, 1000)] public float weatherScale;
    [Range(0, 1000)] public float curlNoiseScale;
    [Range(0, 1000)] public float curlDistortionFactor;

    [Range(0, 1)] public float forwardScatteringFactor;
    [Range(0, 1)] public float extinctionFactor;

    
    public float silverIntensity;
    [Range(0, 1)] public float silverSpread;
    public float brightness;


    [Range(0, 1)] public float coneSpread;

    public Vector3 PlanetZeroCoord;
    public float planetRadius;
    public float startHeight;
    public float cloudThickness;

    [Header("Debug Keyword")] 
    public bool mappedWeatherTex;
    public bool baseCloudOnly;

    private void OnEnable()
    {
        if (_CloudMat == null)
            _CloudMat = new Material(Shader.Find("Hidden/Cloud"));

        if (_BlendCloud == null)
        {
            _BlendCloud = new Material(Shader.Find("Hidden/BlendCloud"));
        }
        SetDebugKeyword("SHOW_MAPPED_WEATHER_TEX", mappedWeatherTex);
        SetDebugKeyword("BASE_CLOUD_ONLY", baseCloudOnly);
        
        mainCamera.depthTextureMode = DepthTextureMode.Depth;

        mainCamera.allowMSAA = true;
    }

    private void Start()
    {
        _shapeRt3d = generator.ShapeRT;
        _detailRt3d = generator.DetailRT;
        _CloudMat.SetVector("_Random", new Vector4(Random.value, Random.value, 0, 0));

        //Debug.Log(SystemInfo.graphicsDeviceType);
    }

    private void Update()
    {
        _weatherTex = weatherSystem.weatherTexture;
    }

    private void UpdateCloudMaterial()
    {
        _CloudMat.SetTexture("_ShapeTex", _shapeRt3d);
        _CloudMat.SetTexture("_DetailTex", _detailRt3d);
        _CloudMat.SetTexture("_WeatherTex", _weatherTex);
        _CloudMat.SetTexture("_CurlNoise", curlNoise);
        _CloudMat.SetTexture("_BlueNoise", blueNoise);

        Matrix4x4 frustumCorners = GetFrustumCorners(mainCamera);
        _CloudMat.SetMatrix("_FrustumCorner", frustumCorners);
        _CloudMat.SetMatrix("_CamToWorldMtx", mainCamera.cameraToWorldMatrix);

        _CloudMat.SetFloat("_GlobalCoverage", globalCoverage);

        _CloudMat.SetFloat("_NoiseScale", 0.000001f + noiseScale * 0.000001f);
        _CloudMat.SetFloat("_DetailScale", 0.0001f + detailScale * 0.0001f);
        _CloudMat.SetFloat("_WeatherScale", 0.0000001f + weatherScale * 0.000001f);
        _CloudMat.SetFloat("_CurlNoiseScale", 0.0001f + curlNoiseScale * 0.00001f);
        _CloudMat.SetFloat("_ForwardScattering", forwardScatteringFactor);
        _CloudMat.SetFloat("_CurlDistortionFactor", curlDistortionFactor);
        _CloudMat.SetFloat("_SilverIntensity", silverIntensity);
        _CloudMat.SetFloat("_SilverSpread", silverSpread);
        _CloudMat.SetFloat("_Brightness", brightness);

        _CloudMat.SetVector("_CameraWS", mainCamera.transform.position);
        _CloudMat.SetFloat("_FarPlane", mainCamera.farClipPlane);

        _CloudMat.SetFloat("_ExtinctionFactor", extinctionFactor);


        _CloudMat.SetInt("_Step", maxStep);
        

        _CloudMat.SetVector("_PlanetZeroCoord", PlanetZeroCoord);
        _CloudMat.SetFloat("_PlanetRadius", planetRadius);
        _CloudMat.SetVector("_PLanetCenter", PlanetZeroCoord - new Vector3(0, planetRadius, 0));
        _CloudMat.SetVector("_CloudHeightMinMax",
            new Vector4(startHeight, startHeight + cloudThickness, cloudThickness, 0));
    }

    [ImageEffectOpaque]
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        // if (cloudRT == null)
        // {
        //     cloudRT = new RenderTexture(source.width, source.height,  source.depth, source.format);
        //     cloudRT.enableRandomWrite = true;
        //     cloudRT.Create();
        // }

        UpdateCloudMaterial();
        cloudRT = RenderTexture.GetTemporary(source.width, source.height, source.depth, source.format,
            RenderTextureReadWrite.Default);
        RenderPostProcessingCloud(cloudRT, _CloudMat, 0);

        _BlendCloud.SetTexture("_CloudTex", cloudRT);
        Graphics.Blit(source, destination, _BlendCloud);
        RenderTexture.ReleaseTemporary(cloudRT);
    }

    // private void OnDisable()
    // {
    //     cloudRT.Release();
    // }

    // private void OnDestroy()
    // {
    //     cloudRT.Release();
    // }

    private void RenderPostProcessingCloud(RenderTexture dest, Material mat, int pass)
    {
        RenderTexture.active = dest;

        GL.PushMatrix();
        GL.LoadOrtho();

        mat.SetPass(pass);

        GL.Begin(GL.QUADS);

        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 0.0f); // BL

        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 1.0f); // BR

        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 3.0f); // TR

        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 2.0f); // TL

        GL.End();
        GL.PopMatrix();
    }

    //return each frustum corner ray in eye space
    //because Camera.cameraToWorldMatrix is in OpenGL format, which mean
    //eye space is in right-handed coord, which mean the forward vector point along negative z-axis
    //we negate the Vector.forward to make it point along positive z-axis after convert it to world space
    private Matrix4x4 GetFrustumCorners(Camera cam)
    {
        Matrix4x4 frustumCorners = Matrix4x4.identity;

        float fovHalf = cam.fieldOfView * 0.5f;
        float tanFovHalf = Mathf.Tan(fovHalf * Mathf.Deg2Rad);

        Vector3 right = Vector3.right * tanFovHalf * cam.aspect;
        Vector3 top = Vector3.up * tanFovHalf;

        Vector3 br = -Vector3.forward + right - top;
        Vector3 bl = -Vector3.forward - right - top;
        Vector3 tr = -Vector3.forward + right + top;
        Vector3 tl = -Vector3.forward - right + top;

        frustumCorners.SetRow(0, bl);
        frustumCorners.SetRow(1, br);
        frustumCorners.SetRow(2, tl);
        frustumCorners.SetRow(3, tr);

        return frustumCorners;
    }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.green;


        Matrix4x4 corners = GetFrustumCorners(mainCamera);
        Vector3 pos = mainCamera.transform.position;

        for (int x = 0; x < 4; x++)
        {
            corners.SetRow(x, mainCamera.cameraToWorldMatrix * corners.GetRow(x));
            Gizmos.DrawLine(pos, pos + (Vector3)(corners.GetRow(x)));
        }


        // UNCOMMENT TO DEBUG RAY DIRECTIONS
        Gizmos.color = Color.red;
        int n = 10; // # of intervals

        for (int i = 1; i <= n - 1; i++)
        {
            float t = i / (float)(n);
            Vector3 l = Vector3.Lerp(corners.GetRow(0), corners.GetRow(2), t);
            Vector3 r = Vector3.Lerp(corners.GetRow(1), corners.GetRow(3), t);

            for (int j = 1; j <= n - 1; j++)
            {
                float k = j / (float)(n);
                Vector3 result = Vector3.Lerp(l, r, k);
                Gizmos.DrawLine(pos, pos + result);
            }
        }
    }

    private void SetDebugKeyword(string keyword, bool state)
    {
        if (state && !_CloudMat.IsKeywordEnabled(keyword))
        {
            _CloudMat.EnableKeyword(keyword);
        }
        else if(!state &&  _CloudMat.IsKeywordEnabled(keyword))
        {
            _CloudMat.DisableKeyword(keyword);
        }
    }
    
    private void OnValidate()
    {
        if (Application.isPlaying && _CloudMat != null)
        {
            SetDebugKeyword("SHOW_MAPPED_WEATHER_TEX", mappedWeatherTex);
            SetDebugKeyword("BASE_CLOUD_ONLY", baseCloudOnly);
        }
    }
}