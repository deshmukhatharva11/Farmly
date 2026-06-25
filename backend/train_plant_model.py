import os
import shutil
from pathlib import Path
from ultralytics import YOLO

def main():
    print("=== Farmly: Unified Multi-Crop YOLOv8 Training ===")
    
    # Path setup
    dataset_yaml = "D:/Projects/Farmly/backend/plant_model/data.yaml"
    dest_model_dir = "D:/Projects/Farmly/backend/models"
    dest_model_path = os.path.join(dest_model_dir, "plant_disease_yolo.pt")
    
    if not os.path.exists(dataset_yaml):
        print(f"Error: Dataset configuration file not found at: {dataset_yaml}")
        return
        
    print(f"Dataset configuration: {dataset_yaml}")
    
    # Check if a checkpoint exists to resume
    last_pt = None
    for folder in ["train2", "train"]:
        path = os.path.join("D:/Projects/Farmly/backend/runs/detect/plant_model_run", folder, "weights", "last.pt")
        if os.path.exists(path):
            last_pt = path
            break

    epochs = 10
    batch_size = 16
    imgsz = 512

    try:
        if last_pt:
            print(f"Found checkpoint to resume at: {last_pt}")
            print("Resuming training on CUDA...")
            model = YOLO(last_pt)
            results = model.train(resume=True)
        else:
            print("No checkpoint found. Starting training from pretrained yolov8s.pt on CUDA...")
            model = YOLO("D:/Projects/Farmly/backend/rice_model/yolov8s.pt")
            results = model.train(
                data=dataset_yaml,
                epochs=epochs,
                imgsz=imgsz,
                batch=batch_size,
                device="cuda",
                workers=0,
                project="plant_model_run",
                name="train"
            )
        print("Training completed successfully!")
        
        # Locate best.pt weight file
        best_pt_src = None
        for folder in ["train2", "train"]:
            path = os.path.join("D:/Projects/Farmly/backend/runs/detect/plant_model_run", folder, "weights", "best.pt")
            if os.path.exists(path):
                best_pt_src = path
                break
                
        if best_pt_src and os.path.exists(best_pt_src):
            os.makedirs(dest_model_dir, exist_ok=True)
            print(f"Copying trained weights from {best_pt_src} to: {dest_model_path}")
            shutil.copy(best_pt_src, dest_model_path)
            print("Model weights successfully integrated into Farmly backend!")
        else:
            print("Error: Could not locate best.pt weights in the runs directory.")
            
    except Exception as e:
        print(f"Training failed: {e}")

if __name__ == "__main__":
    main()
