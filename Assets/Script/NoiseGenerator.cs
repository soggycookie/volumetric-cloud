using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using Random = UnityEngine.Random;

public class NoiseGenerator : MonoBehaviour
{
    public int shapeResolution;
    public int detailResolution;

    public ComputeShader noiseCS;

    public RenderTexture ShapeRT => _shapeRT;

    public RenderTexture DetailRT => _detailRT;

    private RenderTexture _shapeRT;
    private RenderTexture _detailRT;
    public Texture2D s;
    public Texture2D d;

    private void OnEnable()
    {
        CreateTexture();
        GenerateShapeRT();
        GenerateDetailRT();
        s = TextureProcessing.RTexture3To2DSlice(_shapeRT, 1);
        d = TextureProcessing.RTexture3To2DSlice(_detailRT, 1);
    }

    private void CreateTexture()
    {
        if (_shapeRT == null)
        {
            _shapeRT = new RenderTexture(shapeResolution, shapeResolution, 0, RenderTextureFormat.ARGB32);
            _shapeRT.dimension = TextureDimension.Tex3D;
            _shapeRT.wrapMode = TextureWrapMode.Repeat;
            _shapeRT.volumeDepth = shapeResolution;
            _shapeRT.enableRandomWrite = true;

            _shapeRT.Create();
        }

        if (_detailRT == null)
        {
            _detailRT = new RenderTexture(detailResolution, detailResolution, 0, RenderTextureFormat.ARGB32);
            _detailRT.dimension = TextureDimension.Tex3D;
            _detailRT.wrapMode = TextureWrapMode.Repeat;
            _detailRT.volumeDepth = detailResolution;
            _detailRT.enableRandomWrite = true;

            _detailRT.Create();
        }
    }

    private void ReleaseTexture()
    {
        _shapeRT.Release();
        _detailRT.Release();
    }

    private int GetKernel(Noise data)
    {
        int worley3DKernel = noiseCS.FindKernel("CSWorley3D");
        int worley2DKernel = noiseCS.FindKernel("CSWorley2D");
        int perlin2DKernel = noiseCS.FindKernel("CSPerlin2D");
        int perlin3DKernel = noiseCS.FindKernel("CSPerlin3D");
        int perlinWorley3DKernel = noiseCS.FindKernel("CSPerlinWorley3D");
        int perlinWorley2DKernel = noiseCS.FindKernel("CSPerlinWorley2D");
        int shapeKernel = noiseCS.FindKernel("CSShape");
        int detailKernel = noiseCS.FindKernel("CSDetail");

        int kernel;

        if (data.noiseType == EnumScript.NoiseType.Worley)
        {
            kernel = data.dimension == EnumScript.Dimension.Two ? worley2DKernel : worley3DKernel;
        }
        else if (data.noiseType == EnumScript.NoiseType.Perlin)
        {
            kernel = data.dimension == EnumScript.Dimension.Two ? perlin2DKernel : perlin3DKernel;
        }
        else if (data.noiseType == EnumScript.NoiseType.PerlinWorley)
        {
            kernel = data.dimension == EnumScript.Dimension.Two ? perlinWorley2DKernel : perlinWorley3DKernel;
        }
        else if (data.noiseType == EnumScript.NoiseType.Shape)
        {
            kernel = shapeKernel;
        }
        else
        {
            kernel = detailKernel;
        }

        return kernel;
    }

    public void Generate(Noise data)
    {
        int kernel = GetKernel(data);

        noiseCS.SetInt("_ActiveChannel", (int)data.activeChannel);
        noiseCS.SetVector("_Resolution", data.resolution);
        noiseCS.SetInt("_Density", data.density);
        noiseCS.SetFloat("_Scale", data.scale);
        noiseCS.SetInt("_Seed", data.seed);
        noiseCS.SetInt("_Octave", data.octaves);
        noiseCS.SetFloat("_Persistence", data.persistence);
        noiseCS.SetFloat("_Lacunarity", data.lacunarity);
        noiseCS.SetBool("_IsInverted", data.isInverted);
        noiseCS.SetFloat("_AngleOffset", data.angleOffset);
        noiseCS.SetFloat("_Exponent", data.exponent);

        if (data.dimension == EnumScript.Dimension.Two)
            noiseCS.SetTexture(kernel, "_rt2D", data.rt);
        else
            noiseCS.SetTexture(kernel, "_rt3D", data.rt);


        int workGroupX = Mathf.CeilToInt((float)data.rt.width / 8);
        int workGroupY = Mathf.CeilToInt((float)data.rt.height / 8);
        int workGroupZ = Mathf.CeilToInt((float)data.rt.volumeDepth / 8);

        noiseCS.Dispatch(kernel, workGroupX, workGroupY, data.dimension == EnumScript.Dimension.Two ? 1 : workGroupZ);
    }

    private void GenerateShapeRT()
    {
        int density = 4;
        float persistence = 0.5f;
        float lacunarity = 2.0f;
        int octaves = 4;

        Noise data = new Noise(
            _shapeRT, EnumScript.Dimension.Three, EnumScript.NoiseType.Shape,
            new Vector3(shapeResolution, shapeResolution, shapeResolution), density, 1, octaves, persistence,
            lacunarity,
            Random.Range(0, 999), true, 1.0f, 1.0f);

        Generate(data);
    }

    private void GenerateDetailRT()
    {
        int density = 2;
        float persistence = 0.5f;
        float lacunarity = 2.0f;
        int octaves = 4;

        Noise data = new Noise(
            _detailRT, EnumScript.Dimension.Three, EnumScript.NoiseType.Detail,
            new Vector3(detailResolution, detailResolution, detailResolution), density, 1, octaves, persistence,
            lacunarity,
            Random.Range(0, 999), true, 1.0f, 1.0f);

        Generate(data);
    }

    private void OnDestroy()
    {
        ReleaseTexture();
    }

    private void OnDisable()
    {
        ReleaseTexture();
    }
}

public struct Noise
{
    public RenderTexture rt;
    public EnumScript.Dimension dimension;
    public EnumScript.NoiseType noiseType;
    public EnumScript.ActiveChannel activeChannel;
    public Vector3 resolution;
    public int density;
    public float scale;
    public int octaves;
    public float persistence;
    public float lacunarity;
    public int seed;
    public bool isInverted;
    public float angleOffset;
    public float exponent;

    public Noise(RenderTexture rt, EnumScript.Dimension dimension, EnumScript.NoiseType noiseType,
        EnumScript.ActiveChannel activeChannel, Vector3 resolution, int density, float scale, int octaves,
        float persistance, float lacunarity, int seed, bool isInverted, float angleOffset, float exponent)
    {
        this.rt = rt;
        this.dimension = dimension;
        this.noiseType = noiseType;
        this.activeChannel = activeChannel;
        this.resolution = resolution;
        this.density = density;
        this.scale = scale;
        this.octaves = octaves;
        this.persistence = persistance;
        this.lacunarity = lacunarity;
        this.seed = seed;
        this.isInverted = isInverted;
        this.angleOffset = angleOffset;
        this.exponent = exponent;
    }

    public Noise(RenderTexture rt, EnumScript.Dimension dimension, EnumScript.NoiseType noiseType, Vector3 resolution,
        int density, float scale, int octaves, float persistance, float lacunarity, int seed, bool isInverted,
        float angleOffset, float exponent) : this()
    {
        this.rt = rt;
        this.dimension = dimension;
        this.noiseType = noiseType;
        this.resolution = resolution;
        this.density = density;
        this.scale = scale;
        this.octaves = octaves;
        this.persistence = persistance;
        this.lacunarity = lacunarity;
        this.seed = seed;
        this.isInverted = isInverted;
        this.angleOffset = angleOffset;
        this.exponent = exponent;

        this.activeChannel = EnumScript.ActiveChannel.R | EnumScript.ActiveChannel.G | EnumScript.ActiveChannel.B |
                             EnumScript.ActiveChannel.A;
    }
}