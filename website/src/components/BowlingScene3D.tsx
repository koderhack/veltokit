import {useMemo, useRef, type RefObject} from 'react';
import {Canvas, useFrame, useThree} from '@react-three/fiber';
import * as THREE from 'three';
import type {Mesh} from 'three';
import {
  ballCanvas,
  crowdCanvas,
  floorCanvas,
  laneCanvas,
  pinCanvas,
  skyCanvas,
  wallCanvas,
} from '@site/src/games/bowlingPixelArt';
import {
  BALL_LANE_Y,
  BALL_START_Z,
  LANE_SURFACE_Y,
  LANE_WIDTH,
  PIN_HEIGHT,
  PINS_Z,
  buildPinLayout,
} from '@site/src/games/bowlingSimulator';
import styles from './BowlingScene3D.module.css';

function pixelMat(canvas: HTMLCanvasElement): THREE.MeshStandardMaterial {
  const tex = new THREE.CanvasTexture(canvas);
  tex.magFilter = THREE.NearestFilter;
  tex.minFilter = THREE.NearestFilter;
  tex.colorSpace = THREE.SRGBColorSpace;
  return new THREE.MeshStandardMaterial({
    map: tex,
    roughness: 0.9,
    metalness: 0.02,
  });
}

function useMaterials() {
  return useMemo(
    () => ({
      lane: pixelMat(laneCanvas()),
      floor: pixelMat(floorCanvas()),
      wall: pixelMat(wallCanvas()),
      crowd: pixelMat(crowdCanvas()),
      sky: pixelMat(skyCanvas()),
      pin: pixelMat(pinCanvas()),
      ball: pixelMat(ballCanvas()),
    }),
    [],
  );
}

function CameraRig({target}: {target: RefObject<Mesh>}): null {
  const {camera} = useThree();
  useFrame(() => {
    const ball = target.current;
    if (!ball) return;
    const p = ball.position;
    const followX = Math.max(-0.58, Math.min(0.58, p.x * 0.32));
    camera.position.set(followX, p.y + 1.35, p.z + 2.4);
    camera.rotation.set(-0.24, 0, 0);
  });
  return null;
}

/** Scena 3D — layout i tekstury jak `BowlingGameScene`. */
function LaneScene(): JSX.Element {
  const mats = useMaterials();
  const ballRef = useRef<Mesh>(null);
  const cycle = useRef(0);
  const pins = useMemo(
    () => buildPinLayout().map((p) => [p.x, LANE_SURFACE_Y, p.z] as [number, number, number]),
    [],
  );

  useFrame((_, delta) => {
    if (!ballRef.current) return;
    cycle.current += delta;
    const t = (cycle.current % 4.2) / 4.2;
    const lateral = Math.sin(cycle.current * 1.35) * 0.46 * 0.88;
    if (t < 0.22) {
      ballRef.current.position.set(lateral, BALL_LANE_Y, BALL_START_Z);
      return;
    }
    const rollT = (t - 0.22) / 0.78;
    const z = BALL_START_Z - rollT * (BALL_START_Z - PINS_Z + 1);
    const hook = Math.sin(cycle.current * 1.2) * 0.25 * (1 - rollT);
    ballRef.current.position.set(lateral * (1 - rollT * 0.3) + hook, BALL_LANE_Y, z);
  });

  return (
    <>
      <CameraRig target={ballRef} />
      <color attach="background" args={['#080a14']} />
      <fog attach="fog" args={['#080a14', 14, 32]} />
      <ambientLight intensity={0.35} />
      <directionalLight position={[4, 8, 6]} intensity={1.05} color="#f2f4ff" />
      <directionalLight position={[-3, 5, -2]} intensity={0.45} color="#8ca8d8" />

      <mesh position={[0, -0.04, 0]} material={mats.floor}>
        <boxGeometry args={[12, 0.08, 28]} />
      </mesh>

      <mesh position={[0, 3.2, PINS_Z - 2.5]} material={mats.sky}>
        <planeGeometry args={[28, 8]} />
      </mesh>

      <mesh position={[0, 2, PINS_Z - 1.2]} material={mats.wall}>
        <boxGeometry args={[12, 4, 0.2]} />
      </mesh>

      {([-1, 1] as const).map((sign) => (
        <group key={sign}>
          <mesh
            position={[sign * 3.2, 1.8, -1.5]}
            rotation={[0, sign * 0.55, 0]}
            material={mats.crowd}>
            <planeGeometry args={[5, 3.5]} />
          </mesh>
          <mesh position={[sign * 0.62, 0.12, 0]}>
            <boxGeometry args={[0.08, 0.08, 14]} />
            <meshStandardMaterial
              color={sign < 0 ? '#ff3399' : '#33e8ff'}
              emissive={sign < 0 ? '#ff3399' : '#33e8ff'}
              emissiveIntensity={0.85}
            />
          </mesh>
          <mesh
            position={[sign * (LANE_WIDTH / 2 + 0.35), LANE_SURFACE_Y - 0.05, 0]}
            material={mats.wall}>
            <boxGeometry args={[0.5, 0.06, 18]} />
          </mesh>
        </group>
      ))}

      <mesh position={[0, LANE_SURFACE_Y - 0.02, 0]} material={mats.lane}>
        <boxGeometry args={[LANE_WIDTH, 0.04, 18]} />
      </mesh>

      <mesh position={[-LANE_WIDTH / 2 - 0.03, LANE_SURFACE_Y + 0.11, 0]} material={mats.wall}>
        <boxGeometry args={[0.06, 0.22, 18]} />
      </mesh>
      <mesh position={[LANE_WIDTH / 2 + 0.03, LANE_SURFACE_Y + 0.11, 0]} material={mats.wall}>
        <boxGeometry args={[0.06, 0.22, 18]} />
      </mesh>

      {pins.map((pos, i) => (
        <group key={i} position={pos}>
          <mesh position={[0, PIN_HEIGHT * 0.4, 0]} material={mats.pin}>
            <coneGeometry args={[0.058, PIN_HEIGHT * 0.8, 12]} />
          </mesh>
          <mesh position={[0, PIN_HEIGHT * 0.98, 0]} material={mats.pin}>
            <sphereGeometry args={[0.035, 8, 8]} />
          </mesh>
        </group>
      ))}

      <mesh ref={ballRef} position={[0, BALL_LANE_Y, BALL_START_Z]} material={mats.ball}>
        <sphereGeometry args={[0.18, 8, 8]} />
      </mesh>
    </>
  );
}

export default function BowlingScene3D(): JSX.Element {
  return (
    <div className={styles.wrap}>
      <Canvas
        className={styles.canvas}
        camera={{fov: 58, near: 0.1, far: 120, position: [0, BALL_LANE_Y + 1.35, BALL_START_Z + 2.4]}}
        dpr={[1, 1.5]}
        gl={{antialias: false, alpha: false}}>
        <LaneScene />
      </Canvas>
      <span className={styles.badge}>Bowling · pixel 3D</span>
    </div>
  );
}
