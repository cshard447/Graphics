using System;
using System.Collections.Generic;
using System.Reflection;
using UnityEngine;
using UnityEngine.Experimental.VFX;

namespace UnityEditor.Experimental
{
    public class VFXNodeProvider : IProvider
    {
        Vector2 m_mousePosition;
        VFXEdContextNode m_contextNode;
        VFXEdDataSource m_dataSource;
        VFXEdCanvas m_canvas;

        public class VFXNodeElement : VFXFilterWindow.Element
        {
            public VFXContextDesc m_Desc;
            public Action<VFXNodeElement> m_SpawnCallback;

            public VFXNodeElement(int level, VFXContextDesc desc, Action<VFXNodeElement> spawncallback)
            {
                this.level = level;
                content = new GUIContent(desc.m_Type + " : " + desc.Name);
                m_Desc = desc;
                m_SpawnCallback = spawncallback;
            }
        }

        internal VFXNodeProvider(Vector2 mousePosition, VFXEdDataSource dataSource, VFXEdCanvas canvas)
        {
            m_mousePosition = mousePosition;
            m_dataSource = dataSource;
            m_canvas = canvas;
        }

        public void CreateComponentTree(List<VFXFilterWindow.Element> tree)
        {
            tree.Add(new VFXFilterWindow.GroupElement(0, "Nodes"));

            tree.Add(new VFXFilterWindow.GroupElement(1, "Events"));
            // TODO: Add Events here

            tree.Add(new VFXFilterWindow.GroupElement(1, "Triggers"));
            // TODO : Add Triggers here

            tree.Add(new VFXFilterWindow.GroupElement(1, "Context Nodes"));

            var contexts = new List<VFXContextDesc>(VFXEditor.ContextLibrary.GetContexts());
            contexts.Sort((blockA, blockB) => {
                int res = blockA.m_Type.CompareTo(blockB.m_Type);
                return res != 0 ? res : blockA.Name.CompareTo(blockB.Name);
            });

            HashSet<string> categories = new HashSet<string>();

            foreach(VFXContextDesc desc in contexts)
            {

                if(!categories.Contains(desc.m_Type.ToString()))
                {
                    categories.Add(desc.m_Type.ToString());
                    tree.Add(new VFXFilterWindow.GroupElement(2, desc.m_Type.ToString()));
                }

                tree.Add(new VFXNodeElement(3, desc, SpawnNode));
            }
        }

        public void SpawnNode(VFXNodeElement node)
        { 
        
            VFXEdContextNodeSpawner spawner = new VFXEdContextNodeSpawner(m_dataSource, m_canvas, m_mousePosition, node.m_Desc);
            spawner.Spawn();
        }

        public bool GoToChild(VFXFilterWindow.Element element, bool addIfComponent)
        {
            if (element is VFXNodeElement)
            {
                ((VFXNodeElement)element).m_SpawnCallback.Invoke((VFXNodeElement)element);
                return true;
            }

            return false;
        }
    }
}
