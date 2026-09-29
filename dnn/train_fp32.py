import csv
import os
import random
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from tqdm import tqdm

from models.resnet8_mnist import ResNet8MNIST


SEED = 42
BATCH_SIZE = 128
EPOCHS = 10
LEARNING_RATE = 1e-3

OUTDIR = Path("results/01_fp32")
CKPTDIR = Path("checkpoints")
OUTDIR.mkdir(parents=True, exist_ok=True)
CKPTDIR.mkdir(parents=True, exist_ok=True)

random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed_all(SEED)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.1307,), (0.3081,)),
])

train_dataset = datasets.MNIST(
    root="./data",
    train=True,
    download=True,
    transform=transform,
)
test_dataset = datasets.MNIST(
    root="./data",
    train=False,
    download=True,
    transform=transform,
)

loader_generator = torch.Generator()
loader_generator.manual_seed(SEED)

train_loader = DataLoader(
    train_dataset,
    batch_size=BATCH_SIZE,
    shuffle=True,
    num_workers=2,
    pin_memory=torch.cuda.is_available(),
    generator=loader_generator,
)
test_loader = DataLoader(
    test_dataset,
    batch_size=BATCH_SIZE,
    shuffle=False,
    num_workers=2,
    pin_memory=torch.cuda.is_available(),
)

model = ResNet8MNIST().to(device)
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)


@torch.no_grad()
def evaluate():
    model.eval()
    total_loss = 0.0
    correct = 0
    total = 0

    for images, labels in test_loader:
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        outputs = model(images)
        loss = criterion(outputs, labels)

        total_loss += loss.item() * labels.size(0)
        preds = outputs.argmax(dim=1)
        correct += (preds == labels).sum().item()
        total += labels.size(0)

    return total_loss / total, 100.0 * correct / total


history = []
best_accuracy = -1.0
best_epoch = -1

print("===== FP32 TRAINING =====")
print(f"Device        : {device}")
if torch.cuda.is_available():
    print(f"GPU           : {torch.cuda.get_device_name(0)}")
print(f"Train samples : {len(train_dataset)}")
print(f"Test samples  : {len(test_dataset)}")
print(f"Batch size    : {BATCH_SIZE}")
print(f"Epochs        : {EPOCHS}")
print(f"Parameters    : {sum(p.numel() for p in model.parameters())}")
print()

for epoch in range(1, EPOCHS + 1):
    model.train()
    running_loss = 0.0
    seen = 0

    progress = tqdm(train_loader, desc=f"Epoch {epoch:02d}/{EPOCHS}", leave=False)

    for images, labels in progress:
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)

        optimizer.zero_grad(set_to_none=True)
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        batch_n = labels.size(0)
        running_loss += loss.item() * batch_n
        seen += batch_n
        progress.set_postfix(loss=f"{loss.item():.4f}")

    train_loss = running_loss / seen
    test_loss, test_accuracy = evaluate()

    history.append({
        "epoch": epoch,
        "train_loss": train_loss,
        "test_loss": test_loss,
        "test_accuracy": test_accuracy,
    })

    print(
        f"Epoch {epoch:02d}: "
        f"train_loss={train_loss:.5f}  "
        f"test_loss={test_loss:.5f}  "
        f"test_accuracy={test_accuracy:.3f}%"
    )

    if test_accuracy > best_accuracy:
        best_accuracy = test_accuracy
        best_epoch = epoch

        torch.save(
            {
                "model_state_dict": model.state_dict(),
                "accuracy": best_accuracy,
                "epoch": best_epoch,
                "seed": SEED,
                "architecture": "ResNet8MNIST",
            },
            CKPTDIR / "resnet8_mnist_fp32.pth",
        )
        print(f"  -> saved new best checkpoint ({best_accuracy:.3f}%)")


with (OUTDIR / "training_history.csv").open("w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=["epoch", "train_loss", "test_loss", "test_accuracy"],
    )
    writer.writeheader()
    writer.writerows(history)

epochs = [row["epoch"] for row in history]
train_losses = [row["train_loss"] for row in history]
test_losses = [row["test_loss"] for row in history]
accuracies = [row["test_accuracy"] for row in history]

plt.figure(figsize=(8, 5))
plt.plot(epochs, train_losses, marker="o", label="Train loss")
plt.plot(epochs, test_losses, marker="o", label="Test loss")
plt.xlabel("Epoch")
plt.ylabel("Cross-entropy loss")
plt.title("FP32 ResNet-8 MNIST Loss")
plt.grid(True, alpha=0.3)
plt.legend()
plt.tight_layout()
plt.savefig(OUTDIR / "loss_curve.png", dpi=180)
plt.close()

plt.figure(figsize=(8, 5))
plt.plot(epochs, accuracies, marker="o")
plt.xlabel("Epoch")
plt.ylabel("Test accuracy (%)")
plt.title("FP32 ResNet-8 MNIST Accuracy")
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(OUTDIR / "accuracy_curve.png", dpi=180)
plt.close()

checkpoint = torch.load(
    CKPTDIR / "resnet8_mnist_fp32.pth",
    map_location=device,
)
model.load_state_dict(checkpoint["model_state_dict"])
model.eval()

confusion = torch.zeros(10, 10, dtype=torch.int64)
sample_images = []
sample_labels = []
sample_preds = []

with torch.no_grad():
    for images, labels in test_loader:
        outputs = model(images.to(device, non_blocking=True))
        preds = outputs.argmax(dim=1).cpu()

        for true_label, pred_label in zip(labels.view(-1), preds.view(-1)):
            confusion[true_label.long(), pred_label.long()] += 1

        if len(sample_images) < 16:
            take = min(16 - len(sample_images), images.size(0))
            sample_images.extend(images[:take].cpu())
            sample_labels.extend(labels[:take].cpu().tolist())
            sample_preds.extend(preds[:take].tolist())

conf_np = confusion.numpy()

plt.figure(figsize=(7, 6))
plt.imshow(conf_np, interpolation="nearest", cmap="viridis")
plt.title("FP32 ResNet-8 MNIST Confusion Matrix")
plt.xlabel("Predicted label")
plt.ylabel("True label")
plt.colorbar()
ticks = np.arange(10)
plt.xticks(ticks, ticks)
plt.yticks(ticks, ticks)

threshold = conf_np.max() / 2.0
for i in range(10):
    for j in range(10):
        value = conf_np[i, j]
        if value:
            plt.text(
                j,
                i,
                str(value),
                ha="center",
                va="center",
                color="white" if value > threshold else "black",
                fontsize=7,
            )

plt.tight_layout()
plt.savefig(OUTDIR / "confusion_matrix.png", dpi=180)
plt.close()

fig, axes = plt.subplots(4, 4, figsize=(8, 8))
for idx, ax in enumerate(axes.flat):
    image = sample_images[idx].squeeze(0).numpy()
    ax.imshow(image, cmap="gray")
    ax.set_title(f"T:{sample_labels[idx]}  P:{sample_preds[idx]}")
    ax.axis("off")

plt.suptitle("FP32 ResNet-8 MNIST Sample Predictions")
plt.tight_layout()
plt.savefig(OUTDIR / "sample_predictions.png", dpi=180)
plt.close()

accuracy_text = (
    "FP32 ResNet-8 MNIST baseline\n"
    f"Best epoch: {best_epoch}\n"
    f"Best test accuracy: {best_accuracy:.3f}%\n"
    f"Seed: {SEED}\n"
    f"Device: {device}\n"
)
(OUTDIR / "accuracy.txt").write_text(accuracy_text)

print()
print("===== FP32 BASELINE COMPLETE =====")
print(f"Best epoch    : {best_epoch}")
print(f"Best accuracy : {best_accuracy:.3f}%")
print("Checkpoint    : checkpoints/resnet8_mnist_fp32.pth")
print("Artifacts     :")
for name in [
    "accuracy.txt",
    "training_history.csv",
    "loss_curve.png",
    "accuracy_curve.png",
    "confusion_matrix.png",
    "sample_predictions.png",
]:
    print(f"  results/01_fp32/{name}")
