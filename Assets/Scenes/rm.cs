using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class rm : MonoBehaviour
{
    // Start is called before the first frame update
    public NoiseGenerator generator;
    public Material material;
    private RenderTexture rt;
    
    void Start()
    {
        if (rt == null)
        {
            rt = new RenderTexture(128, 128, 0, RenderTextureFormat.ARGB32);
            rt.dimension = TextureDimension.Tex3D;
            rt.wrapMode = TextureWrapMode.Repeat;
            rt.volumeDepth = 128;
            rt.enableRandomWrite = true;

            rt.Create();
        }
        
        Noise data = new Noise(rt, EnumScript.Dimension.Three, EnumScript.NoiseType.Perlin,
            new Vector3(128,128,128), 10, 1, 1, 2, 0.5f, 0, true, 1, 1);
        generator.Generate(data);
        material.SetTexture("_Perlin", rt);
    }

    // Update is called once per frame
    void Update()
    {
    }

    private void OnDestroy()
    {
        rt.Release();
    }

    private void OnDisable()
    {
        rt.Release();
    }
}
