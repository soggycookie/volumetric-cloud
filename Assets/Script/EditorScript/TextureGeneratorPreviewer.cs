using System;
using UnityEngine;
using UnityEngine.Serialization;


public abstract class TextureGeneratorPreviewer : MonoBehaviour
{
    [Tooltip("Preview and Render into channels")]
    public EnumScript.ActiveChannel activeChannel;

    public bool grayScalePreview;
    public Vector3Int resolution;

    public Texture2D PreviewTex
    {
        get => _previewTex;
    }

    protected Texture2D _previewTex;
    [HideInInspector] public NoiseTexture noiseTexture;

    public abstract void GeneratePreview();
    public abstract void SetPreviewTexture();
}


public class NoiseTexture
{
    public Texture2D tex2d;
    public EnumScript.Dimension dimension;
    public string name;

    public NoiseTexture(Texture2D tex2d, EnumScript.Dimension dimension, string name)
    {
        this.tex2d = tex2d;
        this.dimension = dimension;
        this.name = name;
    }
}