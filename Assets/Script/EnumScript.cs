using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class EnumScript
{
    public enum TextureType
    {
        Shape = 0,
        Detail = 1
    }

    public enum NoiseType
    {
        Perlin,
        Worley,
        PerlinWorley,
        Shape,
        Detail
    };


    public enum Dimension
    {
        Two = 0,
        Three = 1
    }

    [Flags]
    public enum ActiveChannel
    {
        None = 0,
        R = 1,
        G = 2,
        B = 4, //1 << 2
        A = 8 // 1 << 3
    }
}