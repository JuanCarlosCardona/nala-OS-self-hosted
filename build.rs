use std::{env, fs, process};

fn main(){
    let ld_script_path = match env::var("LD_SCRIPT_PATH") {
        Ok(var) => var,
        _ => process::exit(0),
    };

    let files = fs::read_dir(ld_script_path).unwrap();
    files
        .filer_map(Result::ok)
        .filer(|d| {
            if let some(e) = d.path.extension(){
                e == "ld"
            } else {
                false
            }
        })
        .for_each(|f| println!("cargo:rerun-if-changed={}", f.path.display()));
}