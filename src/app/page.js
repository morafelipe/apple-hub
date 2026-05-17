"use client";
import styles from "./login.module.css";
import { useState, useEffect } from "react";
import Image from "next/image";
import { useForm } from "@/hooks/useForm";
import { postOptions } from "@/lib/utils/optionsFetch";
import { useFetchAction } from "@/hooks/useFetchAction";
import { useRouter } from "next/navigation";
import ErrorMessage from "@/components/common/ErrorMessage";
import Loader from "@/components/common/Loader";

export default function Login() {
  const [visibleError, setVisibleError] = useState(false);
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);
  const [isLoading, setIsLoading] = useState(false);
  const router = useRouter();

  // Warmup ping: wakes the Neon DB before the user submits credentials,
  // reducing the cold-start delay from ~15 s to near-zero on the login request.
  useEffect(() => {
    fetch("/api/health").catch(() => {});
  }, []);

  useEffect(() => {
    async function checkAuth() {
      setIsCheckingAuth(true);
      try {
        const res = await fetch("/api/customers");
        if (res.status === 200) {
          router.push("/dashboard");
        }
      } catch (err) {
        // No autenticado, no hace nada
      } finally {
        setIsCheckingAuth(false);
      }
    }
    checkAuth();
  }, [router]);

  const { form, handleChange } = useForm({ email: "", password: "" });
  const { request } = useFetchAction();

  const onClickLogin = async () => {
    setIsLoading(true);
    try {
      const result = await request("/api/login", postOptions(form));
      console.log("Respuesta login:", result);

      if (result?.success) {
        router.push("/dashboard");
        console.log('Autorizado...');
      } else {
        setVisibleError(true);
      }
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <>
      <Loader isVisible={isCheckingAuth} />
      {!isCheckingAuth && (
        <div className={styles.mainWrapper}>
          <div className={styles.loginBox}>
            <div className={styles.marginLoginBox}>
              <div className={styles.logoApp}>
                <Image
                  src="/applehub-logo.png"
                  alt="Logo de la aplicación"
                  width={155}
                  height={96}
                />
              </div>
              <h1 className={styles.titleH1}>Iniciar Sesión</h1>
              <input
                name="email"
                value={form.email}
                onChange={handleChange}
                className={styles.inputLogin}
                type="text"
                placeholder="Correo electrónico"
              />
              <input
                name="password"
                value={form.password}
                onChange={handleChange}
                className={styles.inputLogin}
                type="password"
                placeholder="Contraseña"
              />
              <button onClick={onClickLogin} disabled={isLoading}>
                {isLoading ? "Iniciando sesión..." : "Ingresar"}
              </button>
              <p className={styles.pLikeLink}>¿No puedes iniciar sesión?</p>
            </div>
          </div>
          {visibleError && <ErrorMessage message={'¡Credenciales inválidas! Verifíca los campos o solicita acceso.'} />}
        </div>
      )}
    </>
  );
}