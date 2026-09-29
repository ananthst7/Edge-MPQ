import csv
from pathlib import Path
import torch
import torch.nn as nn
from models.resnet8_mnist import ResNet8MNIST

OUTDIR = Path("results/01_fp32")
OUTDIR.mkdir(parents=True, exist_ok=True)

model = ResNet8MNIST()
model.eval()
dummy = torch.randn(1, 1, 28, 28)

rows = []
hooks = []

def make_hook(name):
    def hook(module, inputs, output):
        input_shape = tuple(inputs[0].shape)
        output_shape = tuple(output.shape)

        if isinstance(module, nn.Conv2d):
            rows.append({
                "layer": name,
                "type": "Conv2d",
                "input_shape": str(input_shape),
                "output_shape": str(output_shape),
                "cin": module.in_channels,
                "cout": module.out_channels,
                "kernel": f"{module.kernel_size[0]}x{module.kernel_size[1]}",
                "stride": f"{module.stride[0]}x{module.stride[1]}",
                "padding": f"{module.padding[0]}x{module.padding[1]}",
                "groups": module.groups,
                "parameters": module.weight.numel(),
            })
        elif isinstance(module, nn.Linear):
            rows.append({
                "layer": name,
                "type": "Linear",
                "input_shape": str(input_shape),
                "output_shape": str(output_shape),
                "cin": module.in_features,
                "cout": module.out_features,
                "kernel": "-",
                "stride": "-",
                "padding": "-",
                "groups": "-",
                "parameters": module.weight.numel()
                + (module.bias.numel() if module.bias is not None else 0),
            })
    return hook

for name, module in model.named_modules():
    if isinstance(module, (nn.Conv2d, nn.Linear)):
        hooks.append(module.register_forward_hook(make_hook(name)))

with torch.no_grad():
    output = model(dummy)

for hook in hooks:
    hook.remove()

total_params = sum(p.numel() for p in model.parameters())
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)

summary = [
    "===== RESNET-8 MNIST FP32 BASELINE =====",
    "",
    str(model),
    "",
    f"Input shape:       {tuple(dummy.shape)}",
    f"Output shape:      {tuple(output.shape)}",
    f"Total parameters:  {total_params}",
    f"Trainable params:  {trainable_params}",
    "",
    "===== QUANTIZABLE LAYERS =====",
]

for row in rows:
    summary.append(
        f"{row['layer']:24s} "
        f"{row['type']:8s} "
        f"{row['input_shape']:20s} -> "
        f"{row['output_shape']:20s} "
        f"K={row['kernel']:5s} "
        f"params={row['parameters']}"
    )

summary_text = "\n".join(summary)
print(summary_text)
(OUTDIR / "model_summary.txt").write_text(summary_text)

csv_path = OUTDIR / "layer_shapes.csv"
with csv_path.open("w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=[
            "layer", "type", "input_shape", "output_shape", "cin", "cout",
            "kernel", "stride", "padding", "groups", "parameters"
        ],
    )
    writer.writeheader()
    writer.writerows(rows)

print("\nArtifacts written:")
print(" ", OUTDIR / "model_summary.txt")
print(" ", OUTDIR / "layer_shapes.csv")
