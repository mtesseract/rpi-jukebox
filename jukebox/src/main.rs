use std::path::Path;
use std::sync::{Arc, RwLock};

use anyhow::{Context, Result};
use crossbeam_channel::{self, Receiver, Sender};
use rustberry::effects::InterpreterState;
use tracing::{error, debug, info, warn};
use tracing_subscriber::{filter, fmt, prelude::*, reload};

use rustberry::components::config::ConfigLoader;
use rustberry::components::config::ConfigLoaderHandle;
use rustberry::components::tag_mapper::{TagMapper, TagMapperHandle};
use rustberry::effects::{Effect, Interpreter, ProdInterpreter};
use rustberry::input_controller::{
    button::{self, cdev_gpio::CdevGpio},
    rfid_playback::rfid::PlaybackRequestTransmitterRfid,
    Input,
};

use rustberry::player::Player;

const DEFAULT_JUKEBOX_CONFIG_FILE: &str = "/etc/jukebox/conf.yaml";

#[tokio::main]
async fn main() -> Result<()> {
    let filter = filter::LevelFilter::INFO;
    let (filter, reload_handle) = reload::Layer::new(filter);
    tracing_subscriber::registry()
        .with(filter)
        .with(fmt::Layer::default().with_writer(std::io::stderr))
        .init();

    info!("Starting application");

    info!("Using configuration file: {}", DEFAULT_JUKEBOX_CONFIG_FILE);
    let config_loader = ConfigLoader::new(Path::new(DEFAULT_JUKEBOX_CONFIG_FILE), reload_handle.clone())?;
    let config = config_loader.get();

    let mut fltr = filter::LevelFilter::INFO;
    if config.debug {
        fltr = filter::LevelFilter::TRACE;
    }
    info!("Updating log level to: {}", fltr);
    if let Err(err) = reload_handle.modify(|filter| *filter = fltr) {
        error!("Failed to update log level: {}", err);
    }

    info!("Creating TagMapper");
    let base_directory = Path::new(&config.audio_base_directory);
    let tag_mapper_conf_file = Path::new(&config.tag_mapper_configuration_file);
    let tag_mapper_pathbuf = base_directory.join(tag_mapper_conf_file);
    let tag_mapper = TagMapper::new_initialized(&tag_mapper_pathbuf.as_path())
        .context("Creating tag_mapper")?;
    tag_mapper.debug_dump();

    let interpreter_state = Arc::new(RwLock::new(InterpreterState::new()));
    let interpreter_state_copy = interpreter_state.clone();

    // Prepare input channel.
    let (inputs_tx, inputs_rx) = crossbeam_channel::bounded(10);

    info!("Creating Button Controller");
    let _button_controller_handle =
        CdevGpio::new_from_env(inputs_tx.clone()).context("Creating button controller")?;

    if config.enable_rfid_controller {
        info!("Creating PlayBackRequestTransmitter");
        let _playback_controller_handle = PlaybackRequestTransmitterRfid::new(inputs_tx.clone())
            .context("Creating playback controller")?;
    } else {
        warn!("Skipping creation of PlayBackRequestTransmitter: RFID controller disabled.");
    }

    // Effect interpreter.
    let (effect_tx, effect_rx) = crossbeam_channel::bounded::<Effect>(50);
    let config_loader_copy = config_loader.clone();
    tokio::task::spawn_blocking(move || {
        // Create Effects Channel and Interpreter.
        let mut interpreter =
            ProdInterpreter::new(config_loader_copy, interpreter_state_copy).context("Creating production interpreter").unwrap();

        info!("Waiting for interpreter readiness");
        interpreter
            .wait_until_ready()
            .context("Waiting for interpreter readiness").unwrap();
        for effect in effect_rx {
            debug!("interpreting effect {:?}", effect);
            if let Err(err) = interpreter.interprete(effect.clone()) {
                error!("interpreting effect {:?} failed: {}", effect, err);
            }
        }
    });

    // Execute Application Logic.
    info!("Running application");
    let _res = run(
        config_loader,
        inputs_rx,
        effect_tx,
        tag_mapper,
        interpreter_state,
    )
    .unwrap();
    unreachable!();
}

fn run(
    config: ConfigLoaderHandle,
    input: Receiver<Input>,
    effect_tx: Sender<Effect>,
    tag_mapper: TagMapperHandle,
    interpreter_state: Arc<RwLock<InterpreterState>>,
) -> Result<()> {
    let mut player = Player::new(effect_tx.clone(), config.clone(), tag_mapper, interpreter_state)?;
    for input_ev in input {
        debug!("Processing winput event: {:?}", input_ev);
        let res = process_ev(config.clone(), &mut player, input_ev.clone(), effect_tx.clone());
        match res {
            Err(err) => {
                error!("Failed to process input event {:?}: {}", input_ev, err);
            }
            Ok(effects) => {
                for effect in effects {
                    if let Err(err) = effect_tx.send(effect.clone()) {
                        error!("Failed to send output effect {:?}: {}", effect, err);
                    }
                }
            }
        }
    }
    unreachable!()
}

fn process_ev(
    config_loader: ConfigLoaderHandle,
    player: &mut Player,
    input: Input,
    _output: Sender<Effect>,
) -> Result<Vec<Effect>> {
    let config = config_loader.get();

    match input {
        Input::Button(cmd) => match cmd {
            button::Command::VolumeUp => {
                let cmd = config
                    .volume_up_command
                    .clone()
                    .unwrap_or_else(|| "pactl set-sink-volume 0 +10%".to_string());
                return Ok(vec![Effect::GenericCommand(cmd)]);
            }
            button::Command::VolumeDown => {
                let cmd = config
                    .volume_up_command
                    .clone()
                    .unwrap_or_else(|| "pactl set-sink-volume 0 -10%".to_string());
                return Ok(vec![Effect::GenericCommand(cmd)]);
            }
            button::Command::PauseContinue => {
                player.pause_continue_command()?;
                return Ok(vec![]);
            }
        },
        Input::Playback(request) => {
            player.playback(request.clone())?;
            return Ok(vec![]);
        }
    }
}
