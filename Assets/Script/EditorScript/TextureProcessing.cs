using System.IO;
using Unity.Collections;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;

public static class TextureProcessing
{
    public static void SaveAsAsset(string path, string name, Texture2D tex)
    {
        byte[] bytes = tex.EncodeToPNG();

        if (!Directory.Exists(path))
        {
            Directory.CreateDirectory(path);
        }

        System.IO.File.WriteAllBytes(path + "/" + name + ".png", bytes);

#if UNITY_EDITOR
        UnityEditor.AssetDatabase.Refresh();
#endif
    }

    public static void SaveRT3DToTexture3DAsset(RenderTexture rt3D, string pathWithoutAssetsAndExtension)
    {
        int width = rt3D.width, height = rt3D.height, depth = rt3D.volumeDepth;
        var a = new NativeArray<byte>(width * height * depth * 4, Allocator.Persistent,
            NativeArrayOptions
                .UninitializedMemory); //change if format is not 8 bits (i was using R8_UNorm) (create a struct with 4 bytes etc)
        AsyncGPUReadback.RequestIntoNativeArray(ref a, rt3D, 0, (_) =>
        {
            Texture3D output = new Texture3D(width, height, depth, rt3D.graphicsFormat, TextureCreationFlags.None);
            output.SetPixelData(a, 0);
            output.Apply(updateMipmaps: false, makeNoLongerReadable: true);
            AssetDatabase.CreateAsset(output, $"Assets/{pathWithoutAssetsAndExtension}.asset");
            AssetDatabase.SaveAssetIfDirty(output);
            a.Dispose();
            rt3D.Release();
        });
    }

    public static void SaveAsAsset(string name, RenderTexture rt3D)
    {
        SaveRT3DToTexture3DAsset(rt3D, name);

#if UNITY_EDITOR
        UnityEditor.AssetDatabase.Refresh();
#endif
    }

    public static Texture2D RTexture3To2DSlice(RenderTexture rt3D, float zSlice)
    {
        Texture2D tex = new Texture2D(rt3D.width, rt3D.height);


        //RenderTexture rt = new RenderTexture(resolution, resolution, 0);
        RenderTexture rt = RenderTexture.GetTemporary(rt3D.width, rt3D.height, 0);
        rt.enableRandomWrite = true;

        Shader extractSlice = Shader.Find("Custom/ExtractTex2D");

        Material mat = new Material(extractSlice);
        mat.SetFloat("_ZSlice", zSlice);

        RenderTexture.active = rt3D;
        Graphics.Blit(rt3D, rt, mat);

        RenderTexture.active = rt;
        tex.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
        tex.Apply();
        RenderTexture.active = null;
        RenderTexture.ReleaseTemporary(rt);

        return tex;
    }

    public static Texture2D RTexture2ToTex2(RenderTexture rt2d)
    {
        Texture2D tex = new Texture2D(rt2d.width, rt2d.height);

        RenderTexture.active = rt2d;
        tex.ReadPixels(new Rect(0, 0, rt2d.width, rt2d.height), 0, 0);
        tex.Apply();
        RenderTexture.active = null;

        return tex;
    }

    public static Texture2D ConvertToGrayscale(Texture2D sourceTexture)
    {
        int width = sourceTexture.width;
        int height = sourceTexture.height;

        Texture2D resultTexture = new Texture2D(width, height);

        Color[] sourcePixels = sourceTexture.GetPixels();
        Color[] resultPixels = new Color[sourcePixels.Length];

        for (int i = 0; i < sourcePixels.Length; i++)
        {
            Color pixel = sourcePixels[i];

            float v = Mathf.Max(pixel.r, pixel.g, pixel.b, pixel.a);

            resultPixels[i] = new Color(v, v, v, v);
        }

        resultTexture.SetPixels(resultPixels);
        resultTexture.Apply();

        return resultTexture;
    }

    public static Texture2D ReadChannelMask(Texture2D tex, ActiveChannelMask mask)
    {
        Texture2D newTex = new Texture2D(tex.width, tex.height);


        Color[] col = tex.GetPixels();
        Color[] newCol = new Color[col.Length];

        for (int i = 0; i < col.Length; i++)
        {
            Color c = new Color(0, 0, 0, 0);

            if (mask.R)
                c.r = col[i].r;
            if (mask.G)
                c.g = col[i].g;
            if (mask.B)
                c.b = col[i].b;
            if (mask.A)
                c.a = col[i].a;

            newCol[i] = c;
        }

        newTex.SetPixels(newCol);
        newTex.Apply();

        return newTex;
    }

    public static ActiveChannelMask CheckActiveTexChannel(EnumScript.ActiveChannel channels)
    {
        bool R = false, G = false, B = false, A = false;

        uint bitmaskR = (uint)1 << 0; //0001      
        uint activeRedChannel = bitmaskR & (uint)channels;
        if (activeRedChannel == 1)
            R = true;

        uint bitmaskG = (uint)1 << 1; //0010
        uint activeGreenChannel = bitmaskG & (uint)channels; //0010
        if (activeGreenChannel == 2)
            G = true;

        uint bitmaskB = (uint)1 << 2;
        uint activeBlueChannel = bitmaskB & (uint)channels;
        if (activeBlueChannel == 4)
            B = true;

        uint bitmaskA = (uint)1 << 3;
        uint activeAlphaChannel = bitmaskA & (uint)channels;
        if (activeAlphaChannel == 8)
            A = true;

        return new ActiveChannelMask(R, G, B, A);
    }
}

public struct ActiveChannelMask
{
    public bool R, G, B, A;

    public ActiveChannelMask(bool R, bool G, bool B, bool A)
    {
        this.R = R;
        this.G = G;
        this.B = B;
        this.A = A;
    }
}