using UnityEngine;
using UnityEngine.Serialization;
using UnityEngine.SocialPlatforms;

public class WeatherMapGeneratorPreviewer : TextureGeneratorPreviewer
{
    [Space(20)] public WeatherSystem system;
    [Space(20)] public int seed;
    public int overallDensity;
    [Range(0, 1)] public float fallOffCoverage;
    [Range(0, 1)] public float scaleDensity;

    [Range(0, 1)] public float lowAltitudeCloudBias;
    [Range(0, 1)] public float mediumAltitudeCloudBias;
    [Range(0, 1)] public float highAltitudeCloudBias;

    [Range(0, 1)] public float smallCloudBias;

    private RenderTexture _weatherMap;

    private void CreateTexture()
    {
        if (_weatherMap == null || _weatherMap.width != resolution.x || _weatherMap.height != resolution.y)
        {
            if (_weatherMap != null)
                _weatherMap.Release();

            _weatherMap = new RenderTexture(resolution.x, resolution.y, 0);
            _weatherMap.enableRandomWrite = true;
            _weatherMap.Create();
        }
    }

    private void ReleaseTexture()
    {
        _weatherMap.Release();
    }

    public override void GeneratePreview()
    {
        CreateTexture();
        WeatherData data = new WeatherData(
            _weatherMap, resolution, overallDensity, seed, fallOffCoverage, lowAltitudeCloudBias,
            mediumAltitudeCloudBias, highAltitudeCloudBias, smallCloudBias
        );

        system.Generate(data);

        SetPreviewTexture();
    }


    public override void SetPreviewTexture()
    {
        if (_weatherMap != null)
        {
            _previewTex = TextureProcessing.RTexture2ToTex2(_weatherMap);
        }
        else
        {
            _previewTex = null;
        }
    }


    private void OnDisable()
    {
        ReleaseTexture();
    }

    private void OnDestroy()
    {
        ReleaseTexture();
    }

    private void OnValidate()
    {
        if (fallOffCoverage >= 0)
            GeneratePreview();
    }
}