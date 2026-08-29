import type { DecisionTree } from "@/lib/decision-tree/types";

export const V1_DECISION_TREE: DecisionTree = {
  id: "qima-product-classification-v1",
  version: "1.0.0",
  title: "Product Classification",
  entryNodeId: "category",
  nodes: [
    {
      id: "category",
      kind: "category",
      title: "Choose a category",
      description: "Select the category that best matches your product.",
      imageUrl: "https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=1200&q=85",
      rules: [
        { id: "category-industrial", operator: "equals", field: "category", value: "Industrial Machinery", targetNodeId: "industrial-subcategory" },
        { id: "category-construction", operator: "equals", field: "category", value: "Construction & Building Materials", targetNodeId: "construction-subcategory" },
      ],
    },
    {
      id: "industrial-subcategory",
      kind: "subcategory",
      title: "Industrial Machinery",
      description: "Select the closest industrial equipment group.",
      imageUrl: "https://images.unsplash.com/photo-1565043666747-69f6646db940?auto=format&fit=crop&w=1200&q=85",
      rules: [
        { id: "subcategory-cnc", operator: "equals", field: "subcategory", value: "CNC & Machine Tools", targetNodeId: "terminal-cnc" },
        { id: "subcategory-pumps", operator: "equals", field: "subcategory", value: "Pumps & Compressors", targetNodeId: "terminal-pumps" },
      ],
    },
    {
      id: "construction-subcategory",
      kind: "subcategory",
      title: "Construction & Building Materials",
      description: "Select the closest construction material group.",
      imageUrl: "https://images.unsplash.com/photo-1503387762-592deb58ef4e?auto=format&fit=crop&w=1200&q=85",
      rules: [
        { id: "subcategory-cement", operator: "equals", field: "subcategory", value: "Cement & Concrete", targetNodeId: "terminal-cement" },
        { id: "subcategory-bricks", operator: "equals", field: "subcategory", value: "Bricks & Blocks", targetNodeId: "terminal-bricks" },
      ],
    },
    {
      id: "terminal-cnc",
      kind: "terminal",
      title: "CNC & Machine Tools",
      description: "Modern CNC machining and machine-tool equipment.",
      imageUrl: "https://images.unsplash.com/photo-1565610222536-ef125c59da2e?auto=format&fit=crop&w=1200&q=85",
      rules: [],
    },
    {
      id: "terminal-pumps",
      kind: "terminal",
      title: "Pumps & Compressors",
      description: "Industrial pumping and compression equipment.",
      imageUrl: "https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=1200&q=85",
      rules: [],
    },
    {
      id: "terminal-cement",
      kind: "terminal",
      title: "Cement & Concrete",
      description: "Cement, ready-mix concrete and concrete elements.",
      imageUrl: "https://images.unsplash.com/photo-1592394673782-86e7b5ad3b4f?auto=format&fit=crop&w=1200&q=85",
      rules: [],
    },
    {
      id: "terminal-bricks",
      kind: "terminal",
      title: "Bricks & Blocks",
      description: "Construction bricks, concrete blocks and AAC blocks.",
      imageUrl: "https://images.unsplash.com/photo-1531835551805-16d864c8d7e8?auto=format&fit=crop&w=1200&q=85",
      rules: [],
    },
  ],
};
