using System;
using System.Collections;
using UnityEngine;
using Random = UnityEngine.Random;

public class WeatherSystem : MonoBehaviour
{
    public float blendTime = 40;
    public int resolution;
    public MeshRenderer meshRenderer;
    public ComputeShader noiseCS;
    public Camera camera;
    
    public RenderTexture weatherTexture => _rt;
    private RenderTexture _prev;
    private RenderTexture _next;
    private RenderTexture _rt;
    private Material _weatherBlenderMat;
    private bool isWeatherChanging;
    
    private void CreateTexture()
    {
        if (_prev == null)
        {
            _prev = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGB32);
            _prev.enableRandomWrite = true;
            _prev.wrapMode = TextureWrapMode.Repeat;
            _prev.Create();
        }

        if (_next == null)
        {
            _next = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGB32);
            _next.enableRandomWrite = true;
            _next.wrapMode = TextureWrapMode.Repeat;
            _next.Create();
        }

        if (_rt == null)
        {
            _rt = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGB32);
            _rt.enableRandomWrite = true;
            _rt.wrapMode = TextureWrapMode.Repeat;
            _rt.Create();
        }
        
    }

    private void ReleaseTexture()
    {
        _rt.Release();
        _prev.Release();
        _next.Release();
    }

    private WeatherData GetRandomWeatherData(RenderTexture tex)
    {
        WeatherData data = new WeatherData(
            tex, new Vector3(resolution, resolution, resolution), 2,
            Random.Range(0, 999), Mathf.Lerp(0.2f, 0.4f, Random.value),
            Random.value, Random.value, Random.value, Random.value);
        
        return data;
    }
    
    private void OnEnable()
    {
        CreateTexture();
        
        Shader blender = Shader.Find("Hidden/WeatherBlender");
        _weatherBlenderMat = new Material(blender);
        
        Generate(GetRandomWeatherData(_rt));
        meshRenderer.material.SetTexture("_MainTex", _rt);
    }

    private void Start()
    {
        //Blend();
        // Shader test = Shader.Find("Unlit/Test");
        // Material m = new Material(test);
        // Graphics.Blit(null, _next, m);
        // meshRenderer.material.SetTexture("_MainTex", _next);
    }

    public void Blend()
    {
        Graphics.Blit(_rt, _prev);
        Generate(GetRandomWeatherData(_next));
        
        if(isWeatherChanging)
            StopCoroutine(BlendWeatherTexture());
            
        StartCoroutine(BlendWeatherTexture());
    }

    IEnumerator BlendWeatherTexture()
    {
        float time = 0;
        isWeatherChanging = true;
        while (time < blendTime)
        {
            time += Time.deltaTime;
            float t = time / blendTime;
            //Debug.Log(t);
            _weatherBlenderMat.SetTexture("_Prev", _prev);
            _weatherBlenderMat.SetTexture("_Next", _next);
            _weatherBlenderMat.SetFloat("_LerpVal", t);
            
            Graphics.Blit(null, _rt, _weatherBlenderMat);
            meshRenderer.material.SetTexture("_MainTex", _rt);
            yield return null;
        }
        isWeatherChanging = false;

    }

    public void Generate(WeatherData data)
    {
        int kernel = noiseCS.FindKernel("CSWeather2D");
        
        
        noiseCS.SetVector("_Randomness"             , new Vector3(Random.Range(0,10000), Random.Range(0, 1000), Random.value * .5f ));
        noiseCS.SetVector("_Resolution"             , data.resolution);
        noiseCS.SetFloat ("_AngleOffset"            , 1);
        noiseCS.SetBool  ("_IsInverted"             , true);
        noiseCS.SetInt   ("_Density"                , data.density);
        noiseCS.SetInt   ("_Seed"                   , data.seed);
        noiseCS.SetFloat ("_FallOff"                , data.fallOffCoverage);
        noiseCS.SetFloat ("_LowAltitudeCloudBias"   , data.lowAltitudeCloudBias);
        noiseCS.SetFloat ("_MediumAltitudeCloudBias", data.mediumAltitudeCloudBias);
        noiseCS.SetFloat ("_HighAltitudeCloudBias"  , data.highAltitudeCloudBias);
        noiseCS.SetFloat ("_SmallCloudBias"         , data.smallCloudBias);
        noiseCS.SetVector("_WorldSpacePos"          , camera.transform.position);
        noiseCS.SetTexture(kernel, "_weather2D", data.map);
        
        int workGroupX = Mathf.CeilToInt((float) data.map.width / 8);
        int workGroupY = Mathf.CeilToInt((float) data.map.height / 8);
        
        noiseCS.Dispatch(kernel, workGroupX, workGroupY, 1);
    }


    
    private void OnDisable()
    {
        ReleaseTexture();
    }

    private void OnDestroy()
    {
        ReleaseTexture();
    }
}

public struct WeatherData
{
    public RenderTexture map;
    public Vector3 resolution;
    public int density;
    public int seed;
    public float fallOffCoverage;
    public float lowAltitudeCloudBias;
    public float mediumAltitudeCloudBias;
    public float highAltitudeCloudBias;
    public float smallCloudBias;

    public WeatherData(RenderTexture map, Vector3 resolution, int density, int seed, float fallOffCoverage, float lowAltitudeCloudBias, float mediumAltitudeCloudBias, float highAltitudeCloudBias, float smallCloudBias)
    {
        this.map = map;
        this.resolution = resolution;
        this.density = density;
        this.seed = seed;
        this.fallOffCoverage = fallOffCoverage;
        this.lowAltitudeCloudBias = lowAltitudeCloudBias;
        this.mediumAltitudeCloudBias = mediumAltitudeCloudBias;
        this.highAltitudeCloudBias = highAltitudeCloudBias;
        this.smallCloudBias = smallCloudBias;
    }
}