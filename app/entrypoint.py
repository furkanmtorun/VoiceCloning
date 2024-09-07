"""All utilities needed for training model."""

import os
import shutil
import warnings
from distutils.dir_util import copy_tree

import torchaudio
from aws_utils import download_s3_folder, get_project_details_by_id, upload_wav_to_s3
from tortoise.api import TextToSpeech, classify_audio_clip
from tortoise.utils.audio import load_audio, load_voice

warnings.filterwarnings("ignore")


class VoiceCloningModel:
    """Build, train the model and export the voice."""

    def __init__(
        self,
        text: str,
        custom_voice_path: str,
        custom_voice_name: str,
        quality: str,
        voice_diversity_intelligibility_slider: float,
        models_folder_path: str,
    ) -> None:
        self.text = text
        self.custom_voice_name = custom_voice_name
        self.custom_voice_path = custom_voice_path
        self.quality = quality
        self.voice_diversity_intelligibility_slider = (
            voice_diversity_intelligibility_slider
        )
        self.tts = TextToSpeech(models_dir=models_folder_path)

    def load_custom_voices(self) -> None:
        self.path_to_be_feed = f"tortoise/voices/{self.custom_voice_name}"
        os.makedirs(self.path_to_be_feed, exist_ok=True)
        copy_tree(src=self.custom_voice_path, dst=self.path_to_be_feed)
        self.voice_samples, self.conditioning_latents = load_voice(
            self.custom_voice_name
        )
        print(f"Training custom voices are loaded from {self.custom_voice_path}")

    def train_and_export(self, output_path: str) -> None:
        #  my code
        os.makedirs(output_path, exist_ok=True)
        output_path_with_file_name = f"{output_path}/{self.custom_voice_name}.wav"
        generator = self.tts.tts_with_preset(
            self.text,
            voice_samples=self.voice_samples,
            conditioning_latents=self.conditioning_latents,
            preset=self.quality,
            clvp_cvvp_slider=self.voice_diversity_intelligibility_slider,
        )
        torchaudio.save(output_path_with_file_name, generator.squeeze(0).cpu(), 24000)
        print("Voice is exported to", output_path_with_file_name, "!\n")
        shutil.rmtree(self.path_to_be_feed)
        print("Cleanup is done!")


def is_this_from_tortoise(voice_path: str, models_folder_path: str) -> None:
    sampling_rate = 24000
    clip = load_audio(voice_path, sampling_rate=sampling_rate)
    clip = clip[:, :220000]
    prob = classify_audio_clip(clip, models_folder_path) * 100
    print(
        f"This classifier thinks there is a {prob:.3f}% chance that this clip was generated from Tortoise."
    )


if __name__ == "__main__":

    RUNNING_ENV: str = os.getenv("RUNNING_ENV", "local")
    if RUNNING_ENV != "local":
        print("AWS Batch Setup")
        # Fargate over AWS Batch
        PROJECT_ID = os.getenv("PROJECT_ID")
        project_details = get_project_details_by_id(PROJECT_ID)
        MODELS_FOLDER_PATH = "../app/model_files"
        CUSTOM_VOICE_OUTPUT_PATH = "./"
        CUSTOM_VOICE_OUTPUT_NAME = PROJECT_ID
        CUSTOM_VOICE_INPUT_PATH = f"./{PROJECT_ID}"
        QUALITY = project_details["quality"]
        TEXT = project_details["text"]
        download_s3_folder(s3_folder=PROJECT_ID, local_dir=f"./{PROJECT_ID}")
        import os

        print(os.listdir())
        print(os.listdir(f"./{PROJECT_ID}"))
        print(os.listdir(f"./{PROJECT_ID}"))
        print(os.listdir(f"./tortoise/voices"))
    else:
        print("LOCAL Setup")
        # LOCAL env => define hard-coded paths
        MODELS_FOLDER_PATH = "/Users/furkan/Desktop/VoiceCloning/app/model_files"
        CUSTOM_VOICE_INPUT_PATH = "/Users/furkan/Desktop/experiments/input/"
        CUSTOM_VOICE_OUTPUT_PATH = "/Users/furkan/Desktop/experiments/output/"
        CUSTOM_VOICE_OUTPUT_NAME = "demo"
        QUALITY = "ultra_fast"
        TEXT = "Living next to the forest and going for walks on Sundays is a luxury!"

    # Print payload
    print(
        f"\nRunning on {RUNNING_ENV} with following params with {MODELS_FOLDER_PATH=}:\n"
    )
    print(
        f"{CUSTOM_VOICE_INPUT_PATH=}, {CUSTOM_VOICE_OUTPUT_PATH=}, {CUSTOM_VOICE_OUTPUT_NAME=}"
    )
    print(f"{TEXT=}, {QUALITY=}")

    # Generate speech with the custom voice.
    model = VoiceCloningModel(
        text=TEXT,
        # At least 2 audio clips. They must be a WAV file, 6-10 seconds long.
        custom_voice_path=CUSTOM_VOICE_INPUT_PATH,
        custom_voice_name=CUSTOM_VOICE_OUTPUT_NAME,
        # Quality Options: "ultra_fast", "fast" (default), "standard", "high_quality"
        quality=QUALITY,
        #  How to balance vocal diversity with the quality/intelligibility of the spoken text:
        #  0 means highly diverse voice (not recommended), 1 means maximize intellibility | default = 0.5
        voice_diversity_intelligibility_slider=0.5,
        models_folder_path=MODELS_FOLDER_PATH,
    )
    model.load_custom_voices()
    model.train_and_export(output_path=CUSTOM_VOICE_OUTPUT_PATH)

    if RUNNING_ENV != "local":
        # Fargate over AWS Batch
        upload_wav_to_s3(
            local_file_path=f"{CUSTOM_VOICE_OUTPUT_PATH}/{PROJECT_ID}.wav",
            s3_key=f"{PROJECT_ID}.wav",
        )

    ## DIAGNOSIS OF THE VOICE | SECOND FEATURE
    # is_this_from_tortoise(voice_path="/Users/furkan/Desktop/experiments/input/clip1.wav", models_folder_path=MODELS_FOLDER_PATH)
    # is_this_from_tortoise(voice_path="/Users/furkan/Desktop/experiments/output/furki.wav", models_folder_path=MODELS_FOLDER_PATH)
