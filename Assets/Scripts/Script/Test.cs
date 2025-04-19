using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Test : MonoBehaviour
{
    public NoiseGenerator noiseGenerator;
    public Material material;
    public float sigmaA;
    public float sigmaS;
    public float density;
    public float brightness;
    [Range(0.01f, 1)]
    public float stepSize;
    public Color Color;
    [Range(-1, 1)]
    public float asymmetryFactor;
    private RenderTexture s;
    private RenderTexture d;
    

    void Start()
    {
        d = noiseGenerator.DetailRT;
        s = noiseGenerator.ShapeRT;
    }

    // Update is called once per frame
    void Update()
    {
        material.SetTexture("_DetailTex", d);
        material.SetTexture("_ShapeTex", s);
        material.SetFloat("_SigmaA", sigmaA);
        material.SetFloat("_SigmaS", sigmaS);
        material.SetFloat("_Brightness", brightness);
        material.SetFloat("_StepSize", stepSize);
        material.SetColor("_Color", Color);
        material.SetFloat("_AsymmetryFactor", asymmetryFactor);
        material.SetFloat("_SigmaA", density);
    }
}
