using UnityEngine;
using UnityEngine.Rendering;
using Random = UnityEngine.Random;

public class NoiseGeneratorPreviewer : TextureGeneratorPreviewer
{
    [Space(20)] public NoiseGenerator generator;

    [Space(10)] public EnumScript.TextureType textureType;
    public EnumScript.Dimension dimension;
    public EnumScript.NoiseType noiseType;

    public float scale;
    public int density;
    public int octave;
    public float lacunarity;
    public float persistence;
    public int seed;
    public Vector2 offset;
    [Range(0, 10)] public float exponent;

    [Space(10)] [Header("Worley settings")]
    public bool isInverted;

    [Range(0, 1)] public float angleOffset;

    [Space(10)] [Header("3D Noise settings")] [Range(0, 1)]
    public float zSlice;

    private RenderTexture _rt3d;
    private RenderTexture _rt2d;


    public override void GeneratePreview()
    {
        CreateTexture();
        
        if (dimension == EnumScript.Dimension.Two)
        {
            Noise noise = new Noise(
                _rt2d, EnumScript.Dimension.Two, noiseType, activeChannel,
                resolution, density, scale, octave, persistence, lacunarity, 
                seed, isInverted, angleOffset, exponent);
            
            generator.Generate(noise);
        }
        else
        {
            Noise noise = new Noise(
                _rt3d, EnumScript.Dimension.Three, noiseType, activeChannel,
                resolution, density, scale, octave, persistence, lacunarity, 
                seed, isInverted, angleOffset, exponent);
            
            generator.Generate(noise);
        }

        SetPreviewTexture();

        if (dimension == EnumScript.Dimension.Two)
        {
            noiseTexture = new NoiseTexture(_previewTex, dimension, textureType.ToString() + Random.Range(0, 10000000));
        }
        else
        {
            noiseTexture = new NoiseTexture(_previewTex, dimension, textureType.ToString() + Random.Range(0, 10000000));
        }
    }

    public override void SetPreviewTexture()
    {
        if (dimension == EnumScript.Dimension.Two)
        {
            if (_rt2d != null)
            {
                _previewTex = TextureProcessing.RTexture2ToTex2(_rt2d);
            }
            else
            {
                _previewTex = null;
            }
        }
        else
        {
            if (_rt3d != null)
            {
                _previewTex = TextureProcessing.RTexture3To2DSlice(_rt3d, zSlice);
            }
            else
            {
                _previewTex = null;
            }
        }
    }


    void CreateTexture()
    {
        if (_rt3d == null || !_rt3d.IsCreated() || _rt3d.width != resolution.x || _rt3d.height != resolution.y ||
            _rt3d.volumeDepth != resolution.z)
        {
            if (_rt3d != null)
            {
                _rt3d.Release();
            }

            _rt3d = new RenderTexture(resolution.x, resolution.y, 0);
            _rt3d.dimension = TextureDimension.Tex3D;
            _rt3d.wrapMode = TextureWrapMode.Repeat;
            _rt3d.volumeDepth = resolution.z;
            _rt3d.enableRandomWrite = true;

            _rt3d.Create();
        }

        if (_rt2d == null || _rt2d.width != resolution.x || _rt2d.height != resolution.y)
        {
            if (_rt2d != null)
            {
                _rt2d.Release();
            }

            _rt2d = new RenderTexture(resolution.x, resolution.y, 0);
            _rt2d.enableRandomWrite = true;
            _rt2d.wrapMode = TextureWrapMode.Repeat;

            _rt2d.Create();
        }
    }


    void ReleaseRenderTexture()
    {
        _rt3d.Release();
        _rt2d.Release();
    }

    private void OnValidate()
    {
        if (zSlice >= 0 && dimension == EnumScript.Dimension.Three)
        {
            GeneratePreview();
        }

        if (dimension == EnumScript.Dimension.Three)
        {
            if (resolution.x != resolution.y)
            {
                resolution = new Vector3Int(resolution.x, resolution.x, resolution.z);
            }
        }

        if (resolution.x <= 0)
            resolution = new Vector3Int(1, resolution.y, resolution.z);

        if (resolution.y <= 0)
            resolution = new Vector3Int(resolution.x, 1, resolution.z);

        if (resolution.z <= 0)
            resolution = new Vector3Int(resolution.x, 1, resolution.y);

        if (offset != Vector2.zero || seed >= 0)
        {
            GeneratePreview();
        }
    }


    private void OnEnable()
    {
        CreateTexture();
    }

    private void OnDisable()
    {
        ReleaseRenderTexture();
    }

    private void OnDestroy()
    {
        ReleaseRenderTexture();
    }
}