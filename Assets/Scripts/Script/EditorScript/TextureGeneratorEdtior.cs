using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(TextureGeneratorPreviewer), true)]
public class TextureGeneratorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        var noise = (TextureGeneratorPreviewer)target;
        Texture2D n;
        
        if (noise.PreviewTex != null)
        {
            if ((int)noise.activeChannel == -1)
            {
                n = noise.PreviewTex;
            }
            else
            {
                n = TextureProcessing.ReadChannelMask(noise.PreviewTex,
                    TextureProcessing.CheckActiveTexChannel(noise.activeChannel));
            }

            float inspectorWidth = EditorGUIUtility.currentViewWidth;
            float previewSizeX = Mathf.Min(inspectorWidth - 40, 400); // 400 is max size, 40 is padding

            float s = noise.resolution.x / (float)noise.resolution.y;
            float previewSizeY = previewSizeX / s;

            EditorGUILayout.Space(20);
            
            if (s >= 1)
            {
                GUILayout.BeginVertical(GUILayout.Width(400), GUILayout.Height(400));
            }
            else
            {
                GUILayout.BeginHorizontal(GUILayout.Width(400), GUILayout.Height(400));

                previewSizeY = 400;
                previewSizeX = previewSizeY * s;
            }

            GUILayout.FlexibleSpace();


            Rect previewRect = GUILayoutUtility.GetRect(previewSizeX, previewSizeY);
            if (!noise.grayScalePreview)
                EditorGUI.DrawPreviewTexture(previewRect, n);
            else
            {
                EditorGUI.DrawPreviewTexture(previewRect, TextureProcessing.ConvertToGrayscale(n));
            }

            GUILayout.FlexibleSpace();
            if (s >= 1)
            {
                GUILayout.EndVertical();
            }
            else
            {
                GUILayout.EndHorizontal();
            }
        }

        EditorGUILayout.Space(20);

        DrawDefaultInspector();

        EditorGUILayout.Space(10);

        if (GUILayout.Button("Generate", GUILayout.Height(20)))
        {
            noise.GeneratePreview();

            EditorUtility.SetDirty(noise);
        }

        if (GUILayout.Button("Save", GUILayout.Height(20)))
        {
            if (noise.noiseTexture.dimension == EnumScript.Dimension.Two)
            {
                string path = Application.dataPath + "/Texture";

                TextureProcessing.SaveAsAsset(path, noise.noiseTexture.name, noise.noiseTexture.tex2d);
            }
        }
    }
}