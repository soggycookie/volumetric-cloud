using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Serialization;
using Random = UnityEngine.Random;

#if UNITY_EDITOR
public class WeatherMapCombiner : TextureGeneratorPreviewer
{
    public Texture2D R;
    public Texture2D G;
    public Texture2D B;
    public Texture2D A;

    public Shader combineTexture;

    private Material _combineMaterial;
    private RenderTexture _rt;

    private void CreateTexture()
    {
        if (_rt == null || _rt.width != resolution.x || _rt.height != resolution.y)
        {
            if (_rt != null)
            {
                _rt.Release();
            }

            _rt = new RenderTexture(resolution.x, resolution.y, 0);
            _rt.enableRandomWrite = true;
            _rt.Create();
        }
    }

    public override void GeneratePreview()
    {
        CreateTexture();

        if (_combineMaterial == null)
            _combineMaterial = new Material(combineTexture);

        if (R != null)
            _combineMaterial.SetTexture("_R", R);
        if (G != null)
            _combineMaterial.SetTexture("_G", G);
        if (B != null)
            _combineMaterial.SetTexture("_B", B);
        if (A != null)
            _combineMaterial.SetTexture("_A", A);

        Graphics.Blit(null, _rt, _combineMaterial);

        SetPreviewTexture();
        noiseTexture =
            new NoiseTexture(_previewTex, EnumScript.Dimension.Two, "WeatherMap" + Random.Range(0, 10000000));
    }

    public override void SetPreviewTexture()
    {
        if (_rt != null)
        {
            _previewTex = TextureProcessing.RTexture2ToTex2(_rt);
        }
        else
        {
            _previewTex = null;
        }
    }

    private void ReleaseTexture()
    {
        _rt.Release();
    }

    private void OnEnable()
    {
        CreateTexture();
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

#endif